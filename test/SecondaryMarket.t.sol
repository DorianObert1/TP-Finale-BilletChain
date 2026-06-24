// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "./BaseTest.t.sol";
import {BilletChain} from "../src/BilletChain.sol";

contract SecondaryMarketTest is BaseTest {
    uint256 internal price;

    function setUp() public override {
        super.setUp();
        price = expectedPrice();
        // Alice achète le billet 0 ; il servira de support aux tests de revente.
        vm.prank(alice);
        billet.buyTicket{value: price}();
    }

    function _aliceLists(uint256 tokenId, uint256 listPrice) internal {
        vm.startPrank(alice);
        billet.approve(address(billet), tokenId);
        billet.listTicket(tokenId, listPrice);
        vm.stopPrank();
    }

    function test_List_Success() public {
        _aliceLists(0, price);
        assertEq(billet.listingPrice(0), price);
    }

    function test_List_AtCap_Success() public {
        uint256 cap = billet.resaleCapWei(0);
        assertEq(cap, price * 110 / 100);
        _aliceLists(0, cap);
        assertEq(billet.listingPrice(0), cap);
    }

    function test_List_RevertIf_NotOwner() public {
        vm.prank(bob);
        vm.expectRevert(BilletChain.NotTicketOwner.selector);
        billet.listTicket(0, price);
    }

    function test_List_RevertIf_ZeroPrice() public {
        vm.startPrank(alice);
        billet.approve(address(billet), 0);
        vm.expectRevert(BilletChain.ZeroPrice.selector);
        billet.listTicket(0, 0);
        vm.stopPrank();
    }

    function test_List_RevertIf_AboveCap() public {
        uint256 cap = billet.resaleCapWei(0);
        vm.startPrank(alice);
        billet.approve(address(billet), 0);
        vm.expectRevert(abi.encodeWithSelector(BilletChain.PriceAboveCap.selector, cap, cap + 1));
        billet.listTicket(0, cap + 1);
        vm.stopPrank();
    }

    function test_List_RevertIf_NotApproved() public {
        vm.prank(alice);
        vm.expectRevert(BilletChain.NotApprovedForResale.selector);
        billet.listTicket(0, price);
    }

    function test_CancelListing() public {
        _aliceLists(0, price);
        vm.prank(alice);
        billet.cancelListing(0);
        assertEq(billet.listingPrice(0), 0);
    }

    function test_BuyResale_Success() public {
        _aliceLists(0, price);

        uint256 aliceProceedsBefore = billet.proceeds(alice);

        vm.prank(bob);
        billet.buyResale{value: price}(0);

        assertEq(billet.ownerOf(0), bob);
        assertEq(billet.proceeds(alice), aliceProceedsBefore + price);
        assertEq(billet.listingPrice(0), 0); // listing effacé
    }

    function test_BuyResale_EmitsEvent() public {
        _aliceLists(0, price);

        vm.expectEmit(true, true, true, true, address(billet));
        emit BilletChain.TicketResold(0, alice, bob, price);

        vm.prank(bob);
        billet.buyResale{value: price}(0);
    }

    function test_BuyResale_RevertIf_NotListed() public {
        vm.prank(bob);
        vm.expectRevert(BilletChain.NotListed.selector);
        billet.buyResale{value: price}(0);
    }

    function test_BuyResale_RevertIf_IncorrectPayment() public {
        _aliceLists(0, price);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(BilletChain.IncorrectPayment.selector, price, price - 1));
        billet.buyResale{value: price - 1}(0);
    }

    function test_BuyResale_RevertIf_ApprovalRevoked() public {
        _aliceLists(0, price);
        // Alice retire l'approbation après la mise en vente.
        vm.prank(alice);
        billet.approve(address(0), 0);

        vm.prank(bob);
        vm.expectRevert(BilletChain.NotApprovedForResale.selector);
        billet.buyResale{value: price}(0);
    }

    function test_Transfer_ClearsListing() public {
        _aliceLists(0, price);
        vm.prank(alice);
        billet.transferFrom(alice, bob, 0);
        assertEq(billet.listingPrice(0), 0);
    }

    function test_CountListed() public {
        // Alice achète aussi le billet 1, Bob le billet 2.
        vm.prank(alice);
        billet.buyTicket{value: price}();
        vm.prank(bob);
        billet.buyTicket{value: price}();

        _aliceLists(0, price);
        _aliceLists(1, price);

        uint256[] memory ids = new uint256[](4);
        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;
        ids[3] = 99; // billet inexistant : compté comme non listé

        assertEq(billet.countListed(ids), 2);
    }
}
