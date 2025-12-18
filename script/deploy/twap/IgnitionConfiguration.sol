// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

import {Vm} from "forge-std/Vm.sol";
import {ConstantsLib} from "@twap-auction/libraries/ConstantsLib.sol";
import {AuctionStepsBuilder} from "@twap-auction-test/utils/AuctionStepsBuilder.sol";
import {FixedPoint96} from "@twap-auction/libraries/FixedPoint96.sol";
import {IContinuousClearingAuctionConfiguration} from "./Configuration.sol";
import {
    StrategyConfiguration,
    VirtualAztecTokenConfiguration,
    PredicateConfiguration,
    AtpFactoryConfiguration,
    TokenLauncherConfiguration,
    TokenSplits,
    TwapConfig,
    AuctionHookConfiguration
} from "./Configuration.sol";

import {IgnitionSharedDates} from "../IgnitionSharedDates.sol";

contract IgnitionConfiguration is IContinuousClearingAuctionConfiguration {
    using AuctionStepsBuilder for bytes;

    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // Hooks:
    // Before Initialize + Before Swap
    address internal constant POOL_MASK = 0x0000000000000000000000000000000000002080;

    function getGatedRelayerStart() public view returns (uint256) {
        return IgnitionSharedDates.START_TIMESTAMP; // 13th December 2025 09:00 UTC
    }

    function getStrategyConfiguration() public view returns (StrategyConfiguration memory) {
        return StrategyConfiguration({
            positionManager: 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e,
            poolManager: 0x000000000004444c5dc75cB358380D2e3dE08A90,
            hookMask: POOL_MASK
        });
    }

    function getVirtualAztecTokenConfiguration() public view returns (VirtualAztecTokenConfiguration memory) {
        return VirtualAztecTokenConfiguration({name: "VirtualAztecToken", symbol: "VAZT"});
    }

    function getPredicateConfiguration() public view returns (PredicateConfiguration memory) {
        return PredicateConfiguration({
            managerAddress: 0xf6f4A30EeF7cf51Ed4Ee1415fB3bFDAf3694B0d2,
            addressScreeningPolicyId: "x-aztec-aml-008"
        });
    }

    // @todo - unlock start time must be set to the 1 year - should be a synced cliff
    // intention - 1 year from the start of the sale
    function getAtpFactoryConfiguration() public view returns (AtpFactoryConfiguration memory) {
        return AtpFactoryConfiguration({
            unlockCliffDuration: 365 days,
            unlockLockDuration: 365 days,
            executionAllowedAt: 0
        });
    }

    function getTokenLauncherConfiguration() public view returns (TokenLauncherConfiguration memory) {
        return TokenLauncherConfiguration({permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3});
    }

    function getTokenSplits() public view returns (TokenSplits memory) {
        uint128 splitMps = 0.85e7;
        uint128 totalSupply = 1_820_000_000e18;
        uint128 auctionTotalSupply = totalSupply * splitMps / 1e7; // 1547000000
        
        uint128 expectedTotalAuctionSupply = 1_547_000_000e18;
        assert(auctionTotalSupply == expectedTotalAuctionSupply);
        
        uint128 reserveSupply = totalSupply - auctionTotalSupply;

        return TokenSplits({
            totalSupply: totalSupply,
            tokensToSplitToAuctionMps: splitMps,
            auctionTotalSupply: auctionTotalSupply,
            reserveSupply: reserveSupply
        });
    }

    function getTwapConfig() public view returns (TwapConfig memory) {
        uint256 startBlock = IgnitionSharedDates.START_BLOCK_NUMBER;
        // 13th Nov -> 1st Dec -> 2nd Dec
        uint256 contributorPeriodBlockEnd = IgnitionSharedDates.START_BLOCK_NUMBER + IgnitionSharedDates.CONTRIBUTOR_PERIOD_PRE_BIDDING_LENGTH + IgnitionSharedDates.CONTRIBUTOR_PERIOD_BIDDING_LENGTH;

        uint40 duration = IgnitionSharedDates.CONTRIBUTOR_PERIOD_PRE_BIDDING_LENGTH + 
        IgnitionSharedDates.CONTRIBUTOR_PERIOD_BIDDING_LENGTH + 
        IgnitionSharedDates.BLOCKS_12_HOURS + 
        IgnitionSharedDates.BLOCKS_12_HOURS + 
        IgnitionSharedDates.BLOCKS_24_HOURS + 
        IgnitionSharedDates.BLOCKS_24_HOURS + 
        IgnitionSharedDates.BLOCKS_24_HOURS + 
        1;

        bytes memory auctionStepsData =
            AuctionStepsBuilder.init()
            // Contibutor period - 1763024400 -> 1764579600 -- @todo: does contirb period end after first day or here?
            .addStep(0, IgnitionSharedDates.CONTRIBUTOR_PERIOD_PRE_BIDDING_LENGTH)
            // Bidding starts - 25% in first day - smoothly spread
            .addStep(347, IgnitionSharedDates.CONTRIBUTOR_PERIOD_BIDDING_LENGTH) // 347.222222222 per block
            // 2nd day - 12 hr pause on supply release
            .addStep(0, IgnitionSharedDates.BLOCKS_12_HOURS)
            // 2nd day - 12 hr 5% issued
            .addStep(138, IgnitionSharedDates.BLOCKS_12_HOURS) // 138.8888889 per block
            // 3rd day - 24 hr 10% issued
            .addStep(138, IgnitionSharedDates.BLOCKS_24_HOURS) // 138.8888889 per block
            // 4th day - 24 hr 10% issued
            .addStep(138, IgnitionSharedDates.BLOCKS_24_HOURS) // 138.8888889 per block
            // 5th day - 24 hr 10% issued
            .addStep(138, IgnitionSharedDates.BLOCKS_24_HOURS) // 138.8888889 per block
            // final tick - 40% issued
            .addStep(4_024_000, 1);

        uint256 tickSpacing = 7_539_562_940_228_715_434_083;
        uint256 floorPrice = tickSpacing * 100;

        uint256 migrationBlockDelay = 1;
        uint256 sweepBlockDelay = 7200; // 1 day

        return TwapConfig({
            startBlock: startBlock,
            duration: duration,
            endBlock: startBlock + duration,
            claimBlock: startBlock + duration,
            migrationBlock: startBlock + duration + migrationBlockDelay,
            sweepBlock: startBlock + duration + migrationBlockDelay + sweepBlockDelay,
            auctionHookConfiguration: AuctionHookConfiguration({contributorPeriodBlockEnd: contributorPeriodBlockEnd}),
            floorPrice: floorPrice,
            tickSpacing: tickSpacing,
            poolTickSpacing: 10,
            poolLpFee: 500,
            auctionStepsData: auctionStepsData
        });
    }
}
