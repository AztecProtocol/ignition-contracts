// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

import {DressConfiguration} from "./DressConfiguration.sol";
import {IgnitionConfiguration} from "./IgnitionConfiguration.sol";
import {ScheduledDeploymentsConfiguration} from "./ScheduledDeploymentsConfiguration.sol";
import {ConfigurationVariant} from "../SharedConfig.sol";
import {
    StrategyConfiguration,
    VirtualAztecTokenConfiguration,
    PredicateConfiguration,
    AtpFactoryConfiguration,
    TokenLauncherConfiguration,
    TokenSplits,
    TwapConfig,
    AuctionHookConfiguration,
    IContinuousClearingAuctionConfiguration
} from "./Configuration.sol";

contract AuctionConfiguration is IContinuousClearingAuctionConfiguration {
    ConfigurationVariant public immutable VARIANT;
    IContinuousClearingAuctionConfiguration public immutable INNER_CONFIGURATION;

    constructor(ConfigurationVariant _variant) {
        VARIANT = _variant;
        if (VARIANT == ConfigurationVariant.DRESS) {
            require(block.chainid != 1, "Don't use this on mainnet!");
            INNER_CONFIGURATION = new DressConfiguration();
        } else if (VARIANT == ConfigurationVariant.SCHEDULED_DEPLOYMENTS) {
            require(block.chainid != 1, "Don't use this on mainnet!");
            INNER_CONFIGURATION = new ScheduledDeploymentsConfiguration();
        } else if (VARIANT == ConfigurationVariant.IGNITION) {
            INNER_CONFIGURATION = new IgnitionConfiguration();
        } else {
            revert("Invalid variant");
        }
    }

    function getGatedRelayerStart() public view returns (uint256) {
        return INNER_CONFIGURATION.getGatedRelayerStart();
    }

    function getStrategyConfiguration() public view returns (StrategyConfiguration memory) {
        return INNER_CONFIGURATION.getStrategyConfiguration();
    }

    function getVirtualAztecTokenConfiguration() public view returns (VirtualAztecTokenConfiguration memory) {
        return INNER_CONFIGURATION.getVirtualAztecTokenConfiguration();
    }

    function getPredicateConfiguration() public view returns (PredicateConfiguration memory) {
        return INNER_CONFIGURATION.getPredicateConfiguration();
    }

    function getAtpFactoryConfiguration() public view returns (AtpFactoryConfiguration memory) {
        return INNER_CONFIGURATION.getAtpFactoryConfiguration();
    }

    function getTokenLauncherConfiguration() public view returns (TokenLauncherConfiguration memory) {
        return INNER_CONFIGURATION.getTokenLauncherConfiguration();
    }

    function getTokenSplits() public view returns (TokenSplits memory) {
        return INNER_CONFIGURATION.getTokenSplits();
    }

    function getTwapConfig() public view returns (TwapConfig memory) {
        return INNER_CONFIGURATION.getTwapConfig();
    }
}
