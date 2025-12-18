// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

import {DressConfiguration} from "./DressConfiguration.sol";
import {IgnitionConfiguration} from "./IgnitionConfiguration.sol";

import {
    ProtocolTreasuryConfiguration,
    CoinIssuerConfiguration,
    GseConfiguration,
    GovernanceProposerConfiguration,
    FlushRewardConfiguration
} from "./Configuration.sol";

import {IRewardDistributor} from "@aztec/governance/interfaces/IRewardDistributor.sol";
import {GenesisState} from "@aztec/core/interfaces/IRollup.sol";
import {RollupConfigInput} from "@aztec/core/interfaces/IRollup.sol";
import {Timestamp} from "@aztec/shared/libraries/TimeMath.sol";
import {
    Configuration as GovernanceConfiguration,
    ProposeWithLockConfiguration
} from "@aztec/governance/interfaces/IGovernance.sol";
import {RewardBoostConfig} from "@aztec/core/reward-boost/RewardBooster.sol";
import {StakingQueueConfig} from "@aztec/core/libraries/compressed-data/StakingQueueConfig.sol";
import {RewardConfig} from "@aztec/core/libraries/rollup/RewardLib.sol";

import {ConfigurationVariant} from "../SharedConfig.sol";

import {IAztecConfiguration} from "./Configuration.sol";

contract AztecConfiguration is IAztecConfiguration {
    ConfigurationVariant public immutable VARIANT;
    IAztecConfiguration public immutable INNER_CONFIGURATION;

    constructor(ConfigurationVariant _variant) {
        VARIANT = _variant;
        if (VARIANT == ConfigurationVariant.DRESS) {
            require(block.chainid != 1, "Don't use this on mainnet!");
            INNER_CONFIGURATION = new DressConfiguration();
        } else if (VARIANT == ConfigurationVariant.SCHEDULED_DEPLOYMENTS) {
            require(block.chainid != 1, "Don't use this on mainnet!");
            INNER_CONFIGURATION = new DressConfiguration();
        } else if (VARIANT == ConfigurationVariant.IGNITION) {
            INNER_CONFIGURATION = new IgnitionConfiguration();
        } else {
            revert("Invalid variant");
        }
    }

    function getProtocolTreasuryConfiguration() public view returns (ProtocolTreasuryConfiguration memory) {
        return INNER_CONFIGURATION.getProtocolTreasuryConfiguration();
    }

    function getEarliestRewardsClaimableTimestamp() public view returns (Timestamp) {
        return INNER_CONFIGURATION.getEarliestRewardsClaimableTimestamp();
    }

    function getCoinIssuerConfiguration() public view returns (CoinIssuerConfiguration memory) {
        return INNER_CONFIGURATION.getCoinIssuerConfiguration();
    }

    function getGseConfiguration() public view returns (GseConfiguration memory) {
        return INNER_CONFIGURATION.getGseConfiguration();
    }

    function getGovernanceProposerConfiguration() public view returns (GovernanceProposerConfiguration memory) {
        return INNER_CONFIGURATION.getGovernanceProposerConfiguration();
    }

    function getGovernanceConfiguration() public view returns (GovernanceConfiguration memory) {
        return INNER_CONFIGURATION.getGovernanceConfiguration();
    }

    function getFlushRewardConfiguration() public view returns (FlushRewardConfiguration memory) {
        return INNER_CONFIGURATION.getFlushRewardConfiguration();
    }

    function getGenesisState() public view returns (GenesisState memory) {
        return INNER_CONFIGURATION.getGenesisState();
    }

    function getRewardConfiguration(IRewardDistributor _rewardDistributor) public view returns (RewardConfig memory) {
        return INNER_CONFIGURATION.getRewardConfiguration(_rewardDistributor);
    }

    function getRewardBoostConfiguration() public view returns (RewardBoostConfig memory) {
        return INNER_CONFIGURATION.getRewardBoostConfiguration();
    }

    function getStakingQueueConfiguration() public view returns (StakingQueueConfig memory) {
        return INNER_CONFIGURATION.getStakingQueueConfiguration();
    }

    function getRollupConfiguration(IRewardDistributor _rewardDistributor)
        public
        view
        returns (RollupConfigInput memory)
    {
        return INNER_CONFIGURATION.getRollupConfiguration(_rewardDistributor);
    }

    function getRewardDistributorFunding() public view returns (uint256) {
        return INNER_CONFIGURATION.getRewardDistributorFunding();
    }
}
