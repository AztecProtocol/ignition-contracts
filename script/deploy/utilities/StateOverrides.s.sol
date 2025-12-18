// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {Rollup} from "@aztec/core/Rollup.sol";
import {
    CompressedStakingQueueConfig,
    StakingQueueConfigLib,
    StakingQueueConfig
} from "@aztec/core/libraries/compressed-data/StakingQueueConfig.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {G1Point, G2Point} from "@aztec/shared/libraries/BN254Lib.sol";
import {Strings} from "@oz/utils/Strings.sol";

contract StateOverrides is Test {
    function _loadJson() internal returns (string memory) {
        string memory chainId = vm.toString(block.chainid);
        string memory deploymentsDir = vm.envOr("DEPLOYMENTS_DIR", string("../deployments"));
        if (!vm.exists(deploymentsDir)) {
            vm.createDir(deploymentsDir, true);
        }
        string memory inputPath = string.concat(deploymentsDir, "/collective-l1-deployment-", chainId, ".json");
        return vm.readFile(inputPath);
    }

    function _command(address target, bytes32 slot, bytes32 value) internal returns (string memory) {
        // NOTE:  Using the hardhat namespace as anvil is just an alias for it, and it should work better
        //        with tenderly as well.
        string memory command = string.concat(
            "cast rpc hardhat_setStorageAt ",
            Strings.toHexString(address(target)),
            " ",
            Strings.toHexString(uint256(slot), 32),
            " ",
            Strings.toHexString(uint256(value), 32),
            " --rpc $RPC_URL"
        );
        return command;
    }

    function run() public {
        // NOTE:  We need to get a hold of the address, slot, value that we need to update
        //        such that we can most easily try out the staking registry changes.

        string memory json = _loadJson();

        Rollup rollup = Rollup(vm.parseJsonAddress(json, ".rollupAddress"));

        {
            // Updating the input for the entry queue.
            bytes32 slot = bytes32(uint256(keccak256("aztec.core.staking.storage")) + 4);
            StakingQueueConfig memory value = StakingQueueConfigLib.decompress(
                CompressedStakingQueueConfig.wrap(uint256(vm.load(address(rollup), slot)))
            );

            value.bootstrapValidatorSetSize = 1;
            bytes32 newValue = bytes32(CompressedStakingQueueConfig.unwrap(StakingQueueConfigLib.compress(value)));

            emit log("Staking Queue Config");
            emit log_named_address("\tRollup", address(rollup));
            emit log_named_uint("\tSlot number", uint256(slot));
            emit log_named_bytes32("\tValue", newValue);
            emit log(_command(address(rollup), slot, newValue));

            vm.store(address(rollup), slot, newValue);
        }

        {
            // We also need to update the committee set size if we want to see that it is running
            bytes32 slot = bytes32(uint256(keccak256("aztec.validator_selection.storage")) + 2);
            bytes32 value = vm.load(address(rollup), slot);

            bytes32 newValue = bytes32(uint256(value) & ~uint256(type(uint32).max) | 1);

            emit log("Committee Size");
            emit log_named_address("\tRollup", address(rollup));
            emit log_named_uint("\tSlot number", uint256(slot));
            emit log_named_bytes32("\tValue", newValue);
            emit log(_command(address(rollup), slot, newValue));
            vm.store(address(rollup), slot, newValue);
        }

        // NOTE:  Do a fake deposit to see that we can add to queue, flush and then be in committee.

        emit log_named_uint("Queue size", rollup.getEntryQueueLength());
        emit log_named_uint("Validator set size", rollup.getActiveAttesterCount());
        emit log("");

        address attester = makeAddr("random dude number 5");
        IERC20 token = rollup.getStakingAsset();

        deal(address(token), attester, 200_000e18);

        vm.prank(attester);
        token.approve(address(rollup), 200_000e18);
        {
            emit log_named_address("Staking with", attester);

            vm.prank(attester);
            rollup.deposit(
                attester,
                attester,
                G1Point({
                    x: 0x0fef6212d6da91536e36bf75cbde022c61b80c28261b5f71132103dc7abe94b2,
                    y: 0x050bf7681c25f5085d38fb39a0fd63ceed2ae5f40299a9bd5fe9aa0018612d25
                }),
                G2Point({
                    x0: 0x04a34bf40a82affbd40e06fbee969ea0ec7442abc858ba31181a6b418c53c027,
                    x1: 0x1b5c6428b7c4698913662f5e5e7c9acf67f66db576535602126f347346527a56,
                    y0: 0x16af42c6770569122cef6f4a51d0de500a9797b352d93d00617c60154b08b07f,
                    y1: 0x1f9aa1a73178f3ec9a65675570b40ef1eb37eb39e5a0532e5a3aa563af88dd31
                }),
                G1Point({
                    x: 0x197dfae995a78e5a36fc8160c8de27b170bc4269cf8063a69fa38d06a56d62ae,
                    y: 0x0131bc4e2eaec45d1595e68d67e2dcfaca3114434e844b53c5ed8457c4d53c3e
                }),
                true
            );
        }
        emit log_named_uint("Queue size", rollup.getEntryQueueLength());
        emit log_named_uint("Validator set size", rollup.getActiveAttesterCount());
        emit log("");

        {
            emit log("Flushing");
            rollup.flushEntryQueue();
        }
        emit log_named_uint("Queue size", rollup.getEntryQueueLength());
        emit log_named_uint("Validator set size", rollup.getActiveAttesterCount());
        emit log("");

        emit log("Jumping 1 day into the future");
        vm.warp(block.timestamp + 1 days);

        emit log_named_address("Current proposer", rollup.getCurrentProposer());
    }
}
