// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {Lock, LockParams, LockLib} from "test/token-vaults/Importer.sol";

contract LibWrapper {
    function createLock(LockParams memory _params, uint256 _allocation) external pure returns (Lock memory) {
        return LockLib.createLock(_params, _allocation);
    }

    function test() external virtual {
        // @dev To avoid this being included in the coverage results
        // https://github.com/foundry-rs/foundry/issues/2988#issuecomment-1437784542
    }
}

contract CreateLockTest is Test {
    LibWrapper internal libWrapper;

    function setUp() external {
        libWrapper = new LibWrapper();
    }

    function test_WhenLockDurationEQZero() external {
        // it reverts

        vm.expectRevert(LockLib.LockDurationMustBeGTZero.selector);
        libWrapper.createLock(LockParams({startTime: block.timestamp, cliffDuration: 0, lockDuration: 0}), 1000e18);
    }

    modifier whenLockDurationGTZERO() {
        _;
    }

    function test_WhenLockDurationLTCliffDuration(uint256 _cliffDuration, uint256 _lockDuration)
        external
        whenLockDurationGTZERO
    {
        // it reverts

        // Minimum at 2, such that the lock being less than will still be lockduration > 0.
        uint256 cliffDuration = bound(_cliffDuration, 2, type(uint256).max);
        uint256 lockDuration = bound(_lockDuration, 1, cliffDuration - 1);

        vm.expectRevert(
            abi.encodeWithSelector(LockLib.LockDurationMustBeGECliffDuration.selector, lockDuration, cliffDuration)
        );
        libWrapper.createLock(
            LockParams({startTime: block.timestamp, cliffDuration: cliffDuration, lockDuration: lockDuration}), 1000e18
        );
    }

    function test_WhenLockDurationGECliffDuration(uint256 _cliffDuration, uint256 _lockDuration, uint256 _allocation)
        external
        view
        whenLockDurationGTZERO
    {
        // it returns lock with startTime, cliff, endTime, allocation:
        // it returns lock.startTime EQ startTime
        // it returns lock.cliff EQ startTime + cliffDuration
        // it returns lock.endTime EQ startTime + lockDuration
        // it returns lock.allocation EQ allocation

        // Note that we allow allocation to be zero for the lock, just, that the LATP should not allow it.
        uint256 allocation = bound(_allocation, 0, type(uint32).max);
        uint256 lockDuration = bound(_lockDuration, 1, type(uint32).max);
        uint256 cliffDuration = bound(_cliffDuration, 0, lockDuration);

        Lock memory lock = libWrapper.createLock(
            LockParams({startTime: block.timestamp, cliffDuration: cliffDuration, lockDuration: lockDuration}),
            allocation
        );

        assertEq(lock.startTime, block.timestamp, "lock.startTime");
        assertEq(lock.cliff, block.timestamp + cliffDuration, "lock.cliff");
        assertEq(lock.endTime, block.timestamp + lockDuration, "lock.endTime");
        assertEq(lock.allocation, allocation, "lock.allocation");
    }
}
