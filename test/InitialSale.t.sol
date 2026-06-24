// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "./BaseTest.t.sol";
import {BilletChain} from "../src/BilletChain.sol";

contract InitialSaleTest is BaseTest {
    function test_PriceComputedFromOracle() public view {
        assertEq(billet.currentTicketPriceWei(), 0.025 ether);
        assertEq(billet.currentTicketPriceWei(), expectedPrice());
    }

    function test_BuyTicket_Success() public {
        uint256 price = expectedPrice();

        vm.prank(alice);
        uint256 tokenId = billet.buyTicket{value: price}();

        assertEq(tokenId, 0);
        assertEq(billet.ownerOf(tokenId), alice);
        assertEq(billet.purchasePrice(tokenId), price);
        assertEq(billet.totalMinted(), 1);
        assertEq(billet.proceeds(organizer), price);
    }

    function test_BuyTicket_EmitsEvent() public {
        uint256 price = expectedPrice();

        vm.expectEmit(true, true, false, true, address(billet));
        emit BilletChain.TicketSold(0, alice, price);

        vm.prank(alice);
        billet.buyTicket{value: price}();
    }

    function test_BuyTicket_RevertIf_Underpaid() public {
        uint256 price = expectedPrice();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(BilletChain.IncorrectPayment.selector, price, price - 1));
        billet.buyTicket{value: price - 1}();
    }

    function test_BuyTicket_RevertIf_Overpaid() public {
        uint256 price = expectedPrice();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(BilletChain.IncorrectPayment.selector, price, price + 1));
        billet.buyTicket{value: price + 1}();
    }

    function test_BuyTicket_RevertIf_SoldOut() public {
        uint256 price = expectedPrice();

        for (uint256 i; i < MAX_TICKETS; ++i) {
            vm.prank(alice);
            billet.buyTicket{value: price}();
        }

        vm.prank(bob);
        vm.expectRevert(BilletChain.SoldOut.selector);
        billet.buyTicket{value: price}();
    }

    function test_BuyTicket_RevertIf_OracleInvalidPrice() public {
        oracle.setAnswer(0);

        vm.prank(alice);
        vm.expectRevert(BilletChain.InvalidOraclePrice.selector);
        billet.buyTicket{value: 0.025 ether}();
    }

    function test_BuyTicket_RevertIf_StalePrice() public {
        // On avance au-delà de la fraîcheur tolérée sans rafraîchir l'oracle.
        uint256 staleAt = oracle.latestUpdatedAt();
        vm.warp(block.timestamp + MAX_PRICE_AGE + 1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(BilletChain.StalePrice.selector, staleAt));
        billet.buyTicket{value: 0.025 ether}();
    }
}
