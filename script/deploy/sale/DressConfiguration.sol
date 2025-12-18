// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

import {
    ZkPassportConfiguration, PredicateConfiguration, AtpConfiguration, SaleConfiguration
} from "./Configuration.sol";
import {Vm} from "forge-std/Vm.sol";
import {ISaleConfiguration} from "./Configuration.sol";

contract DressConfiguration is ISaleConfiguration {
    Vm public constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function getSaleConfiguration() public view returns (SaleConfiguration memory) {
        uint256 startTime = vm.envUint("CURRENT_TIMESTAMP");
        // @todo alternative or provide as env var like others
        uint256 endTime = startTime + 180 minutes;

        return SaleConfiguration({
            pricePerLot: 0.005 ether,
            supply: 200_000_000e18,
            saleStartTime: uint96(startTime),
            saleEndTime: uint96(endTime)
        });
    }

    function getAtpConfiguration() public view returns (AtpConfiguration memory) {
        return AtpConfiguration({
            unlockCliffDuration: 1,
            unlockLockDuration: 1,
            executionAllowedAt: 0,
            ncatpWithdrawalTimestamp: block.timestamp + 3 hours
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

        string memory defaultDomain = "d1wqou93lfp06y.cloudfront.net";
        string memory domain = vm.envOr("ZKPASSPORT_DOMAIN", defaultDomain);

        return ZkPassportConfiguration({
            verifierAddress: 0x1D000001000EFD9a6371f4d90bB8920D5431c0D8,
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
        return 0x6B9118074aB15142d7524E8c4ea8f62A3Bdb98f1;
    }
}
