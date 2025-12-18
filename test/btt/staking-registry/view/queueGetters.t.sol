// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {StakingRegistryBase} from "../StakingRegistryBase.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {QueueLib} from "src/staking-registry/libs/QueueLib.sol";

contract QueueGetters is StakingRegistryBase {
    address public providerAdmin = makeAddr("providerAdmin");

    function setUp() public override {
        super.setUp();
    }

    function test_getProviderGetters(address[3] memory _attesters) public {
        uint256 providerId = stakingRegistry.registerProvider(providerAdmin, 9000, providerAdmin);

        uint256 queueLength = stakingRegistry.getProviderQueueLength(providerId);
        uint128 firstInQueue = stakingRegistry.getFirstIndexInQueue(providerId);
        uint128 lastInQueue = stakingRegistry.getLastIndexInQueue(providerId);
        assertEq(queueLength, 0);
        assertEq(firstInQueue, 1);
        assertEq(lastInQueue, 1);

        // Add keys
        IStakingRegistry.KeyStore[] memory providerKeys = new IStakingRegistry.KeyStore[](1);
        providerKeys[0] = makeKeyStore(_attesters[0]);

        vm.prank(providerAdmin);
        stakingRegistry.addKeysToProvider(providerId, providerKeys);
        firstInQueue = stakingRegistry.getFirstIndexInQueue(providerId);
        lastInQueue = stakingRegistry.getLastIndexInQueue(providerId);
        queueLength = stakingRegistry.getProviderQueueLength(providerId);
        assertEq(queueLength, 1);
        assertEq(firstInQueue, 1);
        assertEq(lastInQueue, 2);

        // Add more keys
        providerKeys[0] = makeKeyStore(_attesters[1]);

        vm.prank(providerAdmin);
        stakingRegistry.addKeysToProvider(providerId, providerKeys);
        firstInQueue = stakingRegistry.getFirstIndexInQueue(providerId);
        lastInQueue = stakingRegistry.getLastIndexInQueue(providerId);
        queueLength = stakingRegistry.getProviderQueueLength(providerId);
        assertEq(queueLength, 2);
        assertEq(firstInQueue, 1);
        assertEq(lastInQueue, 3);

        // Get the key store at the first index
        IStakingRegistry.KeyStore memory keyStore = stakingRegistry.getValueAtIndexInQueue(providerId, firstInQueue);
        assertEq(keyStore.attester, _attesters[0]);

        // Drip the queue
        vm.prank(providerAdmin);
        stakingRegistry.dripProviderQueue(providerId, 1);
        queueLength = stakingRegistry.getProviderQueueLength(providerId);
        firstInQueue = stakingRegistry.getFirstIndexInQueue(providerId);
        lastInQueue = stakingRegistry.getLastIndexInQueue(providerId);
        assertEq(queueLength, 1);
        assertEq(firstInQueue, 2);
        assertEq(lastInQueue, 3);

        // Get the key store at the first index
        keyStore = stakingRegistry.getValueAtIndexInQueue(providerId, firstInQueue);
        assertEq(keyStore.attester, _attesters[1]);

        // Get the key store at the last index - should revert
        vm.expectRevert(abi.encodeWithSelector(QueueLib.QueueIndexOutOfBounds.selector));
        stakingRegistry.getValueAtIndexInQueue(providerId, lastInQueue);
    }

    function test_getValueAtIndexInQueue_OutOfBounds() public {
        uint256 providerId = stakingRegistry.registerProvider(providerAdmin, 9000, providerAdmin);

        vm.prank(providerAdmin);
        stakingRegistry.addKeysToProvider(providerId, new IStakingRegistry.KeyStore[](1));

        // Above last index
        vm.expectRevert(abi.encodeWithSelector(QueueLib.QueueIndexOutOfBounds.selector));
        stakingRegistry.getValueAtIndexInQueue(providerId, 2);

        vm.prank(providerAdmin);
        stakingRegistry.dripProviderQueue(providerId, 1);

        // Below first index
        vm.expectRevert(abi.encodeWithSelector(QueueLib.QueueIndexOutOfBounds.selector));
        stakingRegistry.getValueAtIndexInQueue(providerId, 0);
    }
}
