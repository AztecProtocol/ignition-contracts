// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Test
import {Test} from "forge-std/Test.sol";

// Contracts
import {QueueLib, Queue} from "src/staking-registry/libs/QueueLib.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";

// Lib
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

// Wrapper to test for reverts at a lower depth
contract QueueWrapper {
    using QueueLib for Queue;

    Queue private queue;

    constructor() {
        queue.init();
    }

    function enqueue(IStakingRegistry.KeyStore memory _keyStore) external {
        queue.enqueue(_keyStore);
    }

    function dequeue() external returns (IStakingRegistry.KeyStore memory) {
        return queue.dequeue();
    }

    function length() external view returns (uint128) {
        return queue.length();
    }

    function getFirstIndex() external view returns (uint128) {
        return queue.getFirstIndex();
    }

    function getLastIndex() external view returns (uint128) {
        return queue.getLastIndex();
    }
}

contract QueueTest is Test {
    QueueWrapper private queue;

    function setUp() external {
        queue = new QueueWrapper();
    }

    function test_WhenNotInitializedAndQueueIsEmpty() external {
        // it reverts when calling dequeue
        // it has length of 0

        assertEq(queue.length(), 0);
        assertEq(queue.getFirstIndex(), 1);
        assertEq(queue.getLastIndex(), 1);

        vm.expectRevert(abi.encodeWithSelector(QueueLib.QueueIsEmpty.selector));
        queue.dequeue();
    }

    function test_WhenAddingAKeyStoreToTheQueue(address[] memory _attesters) external {
        // It updates the length correctly
        // It can be dequeued

        uint128 lengthBefore = queue.length();
        assertEq(lengthBefore, 0);

        IStakingRegistry.KeyStore[] memory keyStores = new IStakingRegistry.KeyStore[](_attesters.length);

        for (uint256 i = 0; i < _attesters.length; i++) {
            keyStores[i] = IStakingRegistry.KeyStore({
                attester: _attesters[i],
                publicKeyG1: BN254Lib.G1Point({x: 0, y: 0}),
                publicKeyG2: BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
                proofOfPossession: BN254Lib.G1Point({x: 0, y: 0})
            });
        }

        for (uint256 i = 0; i < _attesters.length; i++) {
            queue.enqueue(keyStores[i]);
        }

        uint128 lengthAfter = queue.length();
        assertEq(lengthAfter, _attesters.length);

        uint128 firstAfter = queue.getFirstIndex();
        assertEq(firstAfter, 1);

        uint128 lastAfter = queue.getLastIndex();
        assertEq(lastAfter, _attesters.length + 1);

        for (uint256 i = 0; i < _attesters.length; i++) {
            IStakingRegistry.KeyStore memory dequeuedKeyStore = queue.dequeue();
            assertEq(dequeuedKeyStore.attester, _attesters[i]);
        }

        uint128 firstAfterDequeue = queue.getFirstIndex();
        assertEq(firstAfterDequeue, _attesters.length + 1);

        uint128 lastAfterDequeue = queue.getLastIndex();
        assertEq(lastAfterDequeue, _attesters.length + 1);
    }
}
