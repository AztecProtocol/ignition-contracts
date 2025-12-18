// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

import {
    ZkPassportConfiguration, PredicateConfiguration, AtpConfiguration, SaleConfiguration
} from "./Configuration.sol";
import {Vm} from "forge-std/Vm.sol";
import {ISaleConfiguration} from "./Configuration.sol";
import {IgnitionSharedDates} from "../IgnitionSharedDates.sol";
import {ChainEnvironment, SharedConfigGetter} from "../SharedConfig.sol";

// @todo Write a separate one for mainnet
contract IgnitionConfiguration is ISaleConfiguration {
    Vm public constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 public constant SALE_START_TIMESTAMP = IgnitionSharedDates.START_TIMESTAMP; // 13th Nov 2025 14:00 UTC  (9:00 UTC - 5 hours)
    uint256 public constant SALE_END_TIMESTAMP = IgnitionSharedDates.GENESIS_SALE_END_TIMESTAMP;

    SharedConfigGetter public immutable SHARED_CONFIG_GETTER;
    ChainEnvironment public immutable CHAIN_ENVIRONMENT;

    constructor() {
        SHARED_CONFIG_GETTER = new SharedConfigGetter();
        CHAIN_ENVIRONMENT = SHARED_CONFIG_GETTER.getChainEnvironment();
    }

    function getSaleConfiguration() public view returns (SaleConfiguration memory) {
        return SaleConfiguration({
            pricePerLot: 1.4 ether, // 7 ether for 5 sequencers
            // @todo - can be decreased based on expectations
            supply: 200_000_000e18,
            saleStartTime: uint96(SALE_START_TIMESTAMP),
            saleEndTime: uint96(SALE_END_TIMESTAMP)
        });
    }

    function getAtpConfiguration() public view returns (AtpConfiguration memory) {
        return AtpConfiguration({
            unlockCliffDuration: 1,
            unlockLockDuration: 1,
            // @todo - for mainnet is this correct?
            executionAllowedAt: 0,
            ncatpWithdrawalTimestamp: SALE_START_TIMESTAMP + 365 days
        });
    }

    function getZkPassportConfiguration() public view returns (ZkPassportConfiguration memory) {
        if (block.chainid == 31337) {
            return ZkPassportConfiguration({
                verifierAddress: vm.envAddress("ZKPASSPORT_VERIFIER_ADDRESS"),
                domain: "localhost",
                scope: "sanctions"
            });
        }

        string memory defaultDomain = "sale.aztec.network";
        string memory domain = vm.envOr("ZKPASSPORT_DOMAIN", defaultDomain);

        return ZkPassportConfiguration({
            verifierAddress: 0x1D000001000EFD9a6371f4d90bB8920D5431c0D8,  // same address on sepolia and mainnet
            domain: domain, 
            scope: "sanctions"
        });
    }

    function getPredicateConfiguration() public view returns (PredicateConfiguration memory) {
        address managerAddress = 0xb4486F75129B0aa74F99b1B8B7b478Cd4c17e994;
        if (block.chainid == 1) {
            managerAddress = 0xf6f4A30EeF7cf51Ed4Ee1415fB3bFDAf3694B0d2;
        }

        return PredicateConfiguration({
            managerAddress: managerAddress,
            addressScreeningPolicyId: "x-aztec-aml-008",
            kycPolicyId: "x-aztec-identity-008"
        });
    }

    function getPullSplitFactoryAddress() public pure returns (address) {
        // same on sepolia and mainnet
        return 0x6B9118074aB15142d7524E8c4ea8f62A3Bdb98f1;
    }
}
