// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "./BaseTest.t.sol";
import {BilletChain} from "../src/BilletChain.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/// @notice Tente de retirer deux fois en réentrant via le callback de réception d'ETH.
contract ReentrantWithdrawer is IERC721Receiver {
    BilletChain internal billet;
    bool internal attacked;

    constructor(BilletChain billet_) {
        billet = billet_;
    }

    function buy(uint256 price) external payable returns (uint256) {
        return billet.buyTicket{value: price}();
    }

    function list(uint256 tokenId, uint256 price) external {
        billet.approve(address(billet), tokenId);
        billet.listTicket(tokenId, price);
    }

    function attack() external {
        billet.withdraw();
    }

    receive() external payable {
        if (!attacked) {
            attacked = true;
            // La réentrance doit échouer ; on l'avale pour observer le résultat net.
            try billet.withdraw() {} catch {}
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract WithdrawTest is BaseTest {
    uint256 internal price;

    function setUp() public override {
        super.setUp();
        price = expectedPrice();
    }

    function test_Withdraw_Organizer() public {
        vm.prank(alice);
        billet.buyTicket{value: price}();

        uint256 balBefore = organizer.balance;

        vm.prank(organizer);
        billet.withdraw();

        assertEq(organizer.balance, balBefore + price);
        assertEq(billet.proceeds(organizer), 0);
    }

    function test_Withdraw_Seller() public {
        vm.prank(alice);
        billet.buyTicket{value: price}();
        vm.startPrank(alice);
        billet.approve(address(billet), 0);
        billet.listTicket(0, price);
        vm.stopPrank();

        vm.prank(bob);
        billet.buyResale{value: price}(0);

        uint256 balBefore = alice.balance;
        vm.prank(alice);
        billet.withdraw();

        assertEq(alice.balance, balBefore + price);
        assertEq(billet.proceeds(alice), 0);
    }

    function test_Withdraw_EmitsEvent() public {
        vm.prank(alice);
        billet.buyTicket{value: price}();

        vm.expectEmit(true, false, false, true, address(billet));
        emit BilletChain.Withdrawn(organizer, price);

        vm.prank(organizer);
        billet.withdraw();
    }

    function test_Withdraw_RevertIf_Nothing() public {
        vm.prank(bob);
        vm.expectRevert(BilletChain.NothingToWithdraw.selector);
        billet.withdraw();
    }

    function test_Withdraw_ReentrancyDoesNotDrain() public {
        ReentrantWithdrawer attacker = new ReentrantWithdrawer(billet);
        vm.deal(address(attacker), 10 ether);

        // Une vente initiale alimente le contrat (crédit organisateur).
        vm.prank(alice);
        billet.buyTicket{value: price}();

        // L'attaquant achète un billet, puis le revend à Bob pour se créer un solde.
        attacker.buy{value: price}(price);
        attacker.list(1, price);
        vm.prank(bob);
        billet.buyResale{value: price}(1);

        assertEq(billet.proceeds(address(attacker)), price);

        uint256 contractBalBefore = address(billet).balance;
        uint256 attackerBalBefore = address(attacker).balance;

        attacker.attack();

        // L'attaquant ne récupère que sa part, malgré la tentative de réentrance.
        assertEq(billet.proceeds(address(attacker)), 0);
        assertEq(address(attacker).balance, attackerBalBefore + price);
        assertEq(address(billet).balance, contractBalBefore - price);
    }
}
