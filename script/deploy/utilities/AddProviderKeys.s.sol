// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

import {Test} from "forge-std/Test.sol";

import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

struct RegistrationData {
    address attester;
    BN254Lib.G1Point proofOfPossession;
    BN254Lib.G1Point publicKeyInG1;
    BN254Lib.G2Point publicKeyInG2;
}

contract AddProviderKeys is Test {
    address internal constant PROVIDER_ADMIN = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    RegistrationData[] public $registrations;

    function setUp() public {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script/deploy/utilities/data/keys.json");
        string memory json = vm.readFile(path);
        bytes memory jsonBytes = vm.parseJson(json);
        RegistrationData[] memory registrations = abi.decode(jsonBytes, (RegistrationData[]));

        for (uint256 i = 0; i < registrations.length; i++) {
            $registrations.push(registrations[i]);
        }
    }

    function print() public {
        RegistrationData memory r = $registrations[0];
        emit log_named_address("Attester", r.attester);
        emit log_named_bytes32("PublicKeyInG1.x", bytes32(r.publicKeyInG1.x));
        emit log_named_bytes32("PublicKeyInG1.y", bytes32(r.publicKeyInG1.y));
        emit log_named_bytes32("PublicKeyInG2.x0", bytes32(r.publicKeyInG2.x0));
        emit log_named_bytes32("PublicKeyInG2.x1", bytes32(r.publicKeyInG2.x1));
        emit log_named_bytes32("PublicKeyInG2.y0", bytes32(r.publicKeyInG2.y0));
        emit log_named_bytes32("PublicKeyInG2.y1", bytes32(r.publicKeyInG2.y1));
        emit log_named_bytes32("ProofOfPossession.x", bytes32(r.proofOfPossession.x));
        emit log_named_bytes32("ProofOfPossession.y", bytes32(r.proofOfPossession.y));
    }

    function run() public {
        uint256 providerIdentifier = 1;
        address stakingRegistryAddress = 0x4c5859f0F772848b2D91F1D83E2Fe57935348029;

        uint256 start = 0;
        uint256 end = $registrations.length;
        uint256 batchSize = 10;

        while (start < end) {
            uint256 batchEnd = start + batchSize;
            if (batchEnd > end) {
                batchEnd = end;
            }

            IStakingRegistry.KeyStore[] memory keys = new IStakingRegistry.KeyStore[](batchEnd - start);

            for (uint256 i = start; i < batchEnd; i++) {
                emit log_named_address("Adding validator", $registrations[i].attester);
                keys[i - start] = IStakingRegistry.KeyStore({
                    attester: $registrations[i].attester,
                    publicKeyG1: $registrations[i].publicKeyInG1,
                    publicKeyG2: $registrations[i].publicKeyInG2,
                    proofOfPossession: $registrations[i].proofOfPossession
                });
            }

            vm.startBroadcast(PROVIDER_ADMIN);
            IStakingRegistry(stakingRegistryAddress).addKeysToProvider(providerIdentifier, keys);
            vm.stopBroadcast();
            start = batchEnd;
        }
    }
}
