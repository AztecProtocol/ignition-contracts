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

contract ScheduledDeploymentsConfiguration is IContinuousClearingAuctionConfiguration {
    using AuctionStepsBuilder for bytes;

    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // Hooks:
    // Before Initialize + Before Swap
    address internal constant POOL_MASK = 0x0000000000000000000000000000000000002080;

    function getGatedRelayerStart() public view returns (uint256) {
        // The minimum lock is 90 days, so if we set the start time to be almost 90 days in the past
        // we effectively get a lock that active for `effectiveLockTime` (e.g., 90 minutes) instead.
        // By choosing 0 minutes, it will be possible to accelerate and then execute directly.
        uint256 effectiveLockTime = 0 minutes;
        return block.timestamp + effectiveLockTime - 90 days;
    }

    function getStrategyConfiguration() public view returns (StrategyConfiguration memory) {
        // Sepolia uniswap contract addresses
        return StrategyConfiguration({
            positionManager: 0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4,
            poolManager: 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543,
            hookMask: POOL_MASK
        });
    }

    function getVirtualAztecTokenConfiguration() public view returns (VirtualAztecTokenConfiguration memory) {
        return VirtualAztecTokenConfiguration({name: "Virtual-TOKEN", symbol: "VTOKEN"});
    }

    function getPredicateConfiguration() public view returns (PredicateConfiguration memory) {
        return PredicateConfiguration({
            managerAddress: 0xb4486F75129B0aa74F99b1B8B7b478Cd4c17e994,
            addressScreeningPolicyId: "x-aztec-aml-008"
        });
    }

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
        uint128 totalSupply = 3_000_000e18;
        uint128 auctionTotalSupply = totalSupply * splitMps / 1e7;
        uint128 reserveSupply = totalSupply - auctionTotalSupply;

        return TokenSplits({
            totalSupply: totalSupply,
            tokensToSplitToAuctionMps: splitMps,
            auctionTotalSupply: auctionTotalSupply,
            reserveSupply: reserveSupply
        });
    }

    function getTwapConfig() public view returns (TwapConfig memory) {
        // @todo for the mainnet config, no env allowed.
        uint256 startBlock = vm.envUint("AUCTION_START_BLOCK");
        uint256 duration = vm.envUint("AUCTION_DURATION");
        uint256 contributorPeriodBlockEnd = startBlock + vm.envOr("CONTRIBUTOR_PERIOD_BLOCK_END_DELTA", duration / 4);

        uint24 mpsPerBlock = uint24(ConstantsLib.MPS / duration);
        uint24 remainingMPS = ConstantsLib.MPS - mpsPerBlock * uint24(duration - 1);
        bytes memory auctionStepsData =
            AuctionStepsBuilder.init().addStep(mpsPerBlock, uint40(duration - 1)).addStep(remainingMPS, 1);

        uint256 tickSpacing = (22 << FixedPoint96.RESOLUTION) / 10000000; // 0.0000022 ETH
        uint256 floorPrice = ((25 << FixedPoint96.RESOLUTION) / 1000000) / tickSpacing * tickSpacing;

        uint256 migrationBlockDelay = 1;
        uint256 sweepBlockDelay = 1; // @todo consider longer to avoid getting rugged

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
            poolTickSpacing: 6,
            poolLpFee: 300,
            auctionStepsData: auctionStepsData
        });
    }
}
