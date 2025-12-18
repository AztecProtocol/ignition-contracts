// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

import {
    ZkPassportConfiguration, PredicateConfiguration, AtpConfiguration, SaleConfiguration
} from "./Configuration.sol";
import {ConfigurationVariant} from "../SharedConfig.sol";
import {ISaleConfiguration} from "./Configuration.sol";
import {DressConfiguration} from "./DressConfiguration.sol";
import {IgnitionConfiguration} from "./IgnitionConfiguration.sol";

contract GenesisSaleConfiguration is ISaleConfiguration {
    ConfigurationVariant public immutable VARIANT;
    ISaleConfiguration public immutable INNER_CONFIGURATION;

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

    function getSaleConfiguration() public view returns (SaleConfiguration memory) {
        return INNER_CONFIGURATION.getSaleConfiguration();
    }

    function getAtpConfiguration() public view returns (AtpConfiguration memory) {
        return INNER_CONFIGURATION.getAtpConfiguration();
    }

    function getZkPassportConfiguration() public view returns (ZkPassportConfiguration memory) {
        return INNER_CONFIGURATION.getZkPassportConfiguration();
    }

    function getPredicateConfiguration() public view returns (PredicateConfiguration memory) {
        return INNER_CONFIGURATION.getPredicateConfiguration();
    }

    function getPullSplitFactoryAddress() public view returns (address) {
        return INNER_CONFIGURATION.getPullSplitFactoryAddress();
    }
}
