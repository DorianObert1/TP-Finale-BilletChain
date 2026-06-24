// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {BilletChain} from "../src/BilletChain.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

/// @notice Socle commun aux suites de tests : déploie l'oracle factice et le contrat.
abstract contract BaseTest is Test {
    BilletChain internal billet;
    MockV3Aggregator internal oracle;

    address internal organizer = makeAddr("organizer");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant MAX_TICKETS = 3;
    uint256 internal constant NOMINAL_PRICE_EUR = 50;
    uint8 internal constant ORACLE_DECIMALS = 8;
    int256 internal constant ETH_PRICE_EUR = 2000e8; // 1 ETH = 2000 €
    uint256 internal constant MAX_PRICE_AGE = 1 hours;

    function setUp() public virtual {
        // On part d'un timestamp réaliste pour pouvoir tester la péremption.
        vm.warp(1_700_000_000);

        oracle = new MockV3Aggregator(ORACLE_DECIMALS, ETH_PRICE_EUR, block.timestamp);

        vm.prank(organizer);
        billet = new BilletChain("BilletChain", "BLT", MAX_TICKETS, NOMINAL_PRICE_EUR, address(oracle), MAX_PRICE_AGE);

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    /// @dev Prix attendu : 50 € à 2000 €/ETH = 0,025 ETH.
    function expectedPrice() internal pure returns (uint256) {
        return NOMINAL_PRICE_EUR * 1e18 * (10 ** ORACLE_DECIMALS) / uint256(ETH_PRICE_EUR);
    }
}
