// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

import {Test} from "forge-std/Test.sol";

enum ConfigurationVariant {
    DRESS,
    IGNITION,
    SCHEDULED_DEPLOYMENTS
}

enum ChainEnvironment {
    REAL_MAINNET,
    FORKED_MAINNET,
    FRESH_NETWORK
}

contract SharedConfigGetter is Test {
    function getConfigurationVariant() external returns (ConfigurationVariant) {
        string memory configuredConfigurationVariant = vm.envString("CONFIGURATION_VARIANT");
        if (keccak256(abi.encode(configuredConfigurationVariant)) == keccak256(abi.encode("IGNITION"))) {
            emit log("Using IGNITION configuration variant");
            return ConfigurationVariant.IGNITION;
        } else if (
            keccak256(abi.encode(configuredConfigurationVariant)) == keccak256(abi.encode("SCHEDULED_DEPLOYMENTS"))
        ) {
            emit log("Using SCHEDULED_DEPLOYMENTS configuration variant");
            return ConfigurationVariant.SCHEDULED_DEPLOYMENTS;
        } else if (keccak256(abi.encode(configuredConfigurationVariant)) == keccak256(abi.encode("DRESS_REHEARSAL"))) {
            emit log("Using DRESS_REHEARSAL configuration variant");
            return ConfigurationVariant.DRESS;
        } else {
            revert("Invalid configuration variant");
        }
    }

    function getChainEnvironment() external returns (ChainEnvironment) {
        string memory configuredChainEnvironment = vm.envString("CHAIN_ENVIRONMENT_VARIANT");
        if (keccak256(abi.encode(configuredChainEnvironment)) == keccak256(abi.encode("REAL_MAINNET"))) {
            require(block.chainid == 1, "REAL_MAINNET can only be used on mainnet");
            emit log("Using REAL_MAINNET chain environment");
            return ChainEnvironment.REAL_MAINNET;
        } else if (keccak256(abi.encode(configuredChainEnvironment)) == keccak256(abi.encode("FORKED_MAINNET"))) {
            emit log("Using REAL_MAINNET chain environment");
            return ChainEnvironment.FORKED_MAINNET;
        } else if (keccak256(abi.encode(configuredChainEnvironment)) == keccak256(abi.encode("FRESH_NETWORK"))) {
            require(block.chainid != 1, "FRESH_NETWORK can only be used on non-mainnet");
            emit log("Using FRESH_NETWORK chain environment");
            return ChainEnvironment.FRESH_NETWORK;
        } else {
            revert("Invalid chain environment");
        }
    }
}
