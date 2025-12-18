// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {PredicateProvider} from "src/soulbound/providers/PredicateProvider.sol";

// Addresses for mainnet fork 
// Deployed by: 0xE9BDCB32279186b8CaAD1A7Cc6E1044e71359F49
// predicateSanctionsProvider: contract PredicateProvider 0x730a010735492440ed161D9aFB4f95A07a357aea
// predicateKYCProvider: contract PredicateProvider 0x5Bbb0d9CbED5d39e01d9C5BE2a68B761DCcE8809
// predicateVirtualTokenProvider: contract PredicateProvider 0xf5A7405C39cC72751fdd2E357Bd9AD8f22514950
// predicateProviderSale: contract PredicateProvider 0x00E477F7C6a9f73C88e28690bCDdb4cAEAd71aCD


contract DeployPredicateProviders is Script {
    address constant PREDICATE_MANAGER_MAINNET = 0xf6f4A30EeF7cf51Ed4Ee1415fB3bFDAf3694B0d2;

    string constant SCREENING_POLICY = "x-aztec-aml-008";
    string constant IDENTITY_POLICY = "x-aztec-identity-008";

    function run() external returns (PredicateProvider predicateSanctionsProvider, PredicateProvider predicateKYCProvider, PredicateProvider predicateVirtualTokenProvider, PredicateProvider predicateProviderSale) {
        vm.startBroadcast();
        // Soulbound sanctions provider
        predicateSanctionsProvider = new PredicateProvider(msg.sender, PREDICATE_MANAGER_MAINNET, SCREENING_POLICY);
        // Soulbound KYC provider
        predicateKYCProvider = new PredicateProvider(msg.sender, PREDICATE_MANAGER_MAINNET, IDENTITY_POLICY);

        // Virtual token sanctions provider
        predicateVirtualTokenProvider = new PredicateProvider(msg.sender, PREDICATE_MANAGER_MAINNET, SCREENING_POLICY);
        // Genesis sale sanctions provider - alternative beneficiary
        predicateProviderSale = new PredicateProvider(msg.sender, PREDICATE_MANAGER_MAINNET, SCREENING_POLICY);
        vm.stopBroadcast();
    }
}