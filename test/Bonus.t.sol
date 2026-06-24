// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "./BaseTest.t.sol";
import {BilletChain} from "../src/BilletChain.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract BonusTest is BaseTest {
    uint256 internal price;

    function setUp() public override {
        super.setUp();
        price = expectedPrice();
        vm.prank(alice);
        billet.buyTicket{value: price}();
        vm.prank(alice);
        billet.approve(address(billet), 0);
    }

    // --- Frais de plateforme -------------------------------------------------

    function test_PlatformFee_SplitsResale() public {
        vm.prank(organizer);
        billet.setPlatformFeeBps(500); // 5 %

        vm.prank(alice);
        billet.listTicket(0, price);

        uint256 organizerBefore = billet.proceeds(organizer);

        vm.prank(bob);
        billet.buyResale{value: price}(0);

        uint256 fee = price * 500 / 10_000;
        assertEq(billet.proceeds(alice), price - fee);
        assertEq(billet.proceeds(organizer), organizerBefore + fee);
    }

    function test_SetPlatformFee_RevertIf_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        billet.setPlatformFeeBps(500);
    }

    function test_SetPlatformFee_RevertIf_TooHigh() public {
        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSelector(BilletChain.FeeTooHigh.selector, 1_000, 1_001));
        billet.setPlatformFeeBps(1_001);
    }

    // --- Mise en pause d'urgence --------------------------------------------

    function test_Pause_BlocksSales() public {
        vm.prank(organizer);
        billet.pause();

        vm.prank(bob);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        billet.buyTicket{value: price}();

        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        billet.listTicket(0, price);
    }

    function test_Pause_WithdrawStillWorks() public {
        vm.prank(organizer);
        billet.pause();

        // L'organisateur a déjà un solde (vente initiale dans setUp).
        uint256 balBefore = organizer.balance;
        vm.prank(organizer);
        billet.withdraw();
        assertEq(organizer.balance, balBefore + price);
    }

    function test_Pause_RevertIf_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        billet.pause();
    }

    function test_Unpause_RestoresSales() public {
        vm.startPrank(organizer);
        billet.pause();
        billet.unpause();
        vm.stopPrank();

        vm.prank(bob);
        billet.buyTicket{value: price}(); // ne révère plus
        assertEq(billet.ownerOf(1), bob);
    }

    // --- Fuzzing : le plafond ne peut jamais être dépassé --------------------

    function testFuzz_ListNeverAboveCap(uint256 listPrice) public {
        uint256 cap = billet.resaleCapWei(0);

        vm.prank(alice);
        if (listPrice == 0) {
            vm.expectRevert(BilletChain.ZeroPrice.selector);
            billet.listTicket(0, listPrice);
        } else if (listPrice > cap) {
            vm.expectRevert(abi.encodeWithSelector(BilletChain.PriceAboveCap.selector, cap, listPrice));
            billet.listTicket(0, listPrice);
        } else {
            billet.listTicket(0, listPrice);
            assertLe(billet.listingPrice(0), cap); // invariant prouvé
        }
    }
}
