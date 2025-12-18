// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

struct AuctionHookConfiguration {
    uint256 contributorPeriodBlockEnd;
}

struct StrategyConfiguration {
    address positionManager;
    address poolManager;
    address hookMask;
}

struct TokenLauncherConfiguration {
    address permit2;
}

struct PredicateConfiguration {
    address managerAddress;
    string addressScreeningPolicyId;
}

struct AtpFactoryConfiguration {
    uint256 unlockCliffDuration;
    uint256 unlockLockDuration;
    uint256 executionAllowedAt;
}

struct VirtualAztecTokenConfiguration {
    string name;
    string symbol;
}

struct TwapConfig {
    AuctionHookConfiguration auctionHookConfiguration;
    uint256 startBlock;
    uint256 duration;
    uint256 endBlock;
    uint256 claimBlock;
    uint256 migrationBlock;
    uint256 sweepBlock;
    uint256 floorPrice;
    uint256 tickSpacing;
    int24 poolTickSpacing;
    uint24 poolLpFee;
    bytes auctionStepsData;
}

struct TokenSplits {
    uint128 totalSupply;
    uint128 tokensToSplitToAuctionMps;
    uint128 auctionTotalSupply;
    uint128 reserveSupply;
}

interface IContinuousClearingAuctionConfiguration {
    function getGatedRelayerStart() external view returns (uint256);
    function getStrategyConfiguration() external view returns (StrategyConfiguration memory);
    function getVirtualAztecTokenConfiguration() external view returns (VirtualAztecTokenConfiguration memory);
    function getPredicateConfiguration() external view returns (PredicateConfiguration memory);
    function getAtpFactoryConfiguration() external view returns (AtpFactoryConfiguration memory);
    function getTokenLauncherConfiguration() external view returns (TokenLauncherConfiguration memory);
    function getTokenSplits() external view returns (TokenSplits memory);
    function getTwapConfig() external view returns (TwapConfig memory);
}
