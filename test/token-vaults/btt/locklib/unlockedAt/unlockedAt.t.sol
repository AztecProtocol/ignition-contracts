// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {Lock, LockParams, LockLib} from "test/token-vaults/Importer.sol";

contract UnlockedAtTest is Test {
    using LockLib for Lock;

    function test_WhenTimestampIsAtOrAfterEndTime(
        uint256 _timestamp,
        uint256 _allocation,
        uint256 _cliffDuration,
        uint256 _lockDuration
    ) external view {
        // it returns the full allocation

        uint256 allocation = bound(_allocation, 1, type(uint128).max);
        uint256 lockDuration = bound(_lockDuration, 1, type(uint32).max);
        uint256 cliffDuration = bound(_cliffDuration, 0, lockDuration);

        Lock memory lock = LockLib.createLock(
            LockParams({startTime: block.timestamp, cliffDuration: cliffDuration, lockDuration: lockDuration}),
            allocation
        );

        uint256 timestamp = bound(_timestamp, lock.endTime, type(uint256).max);
        uint256 unlockedAt = lock.unlockedAt(timestamp);
        assertEq(unlockedAt, allocation, "unlockedAt");
    }

    function test_WhenTimestampIsBeforeCliff(
        uint256 _timestamp,
        uint256 _allocation,
        uint256 _cliffDuration,
        uint256 _lockDuration
    ) external view {
        // it returns zero

        uint256 allocation = bound(_allocation, 1, type(uint128).max);
        uint256 lockDuration = bound(_lockDuration, 1, type(uint32).max);
        uint256 cliffDuration = bound(_cliffDuration, 1, lockDuration);

        Lock memory lock = LockLib.createLock(
            LockParams({startTime: block.timestamp, cliffDuration: cliffDuration, lockDuration: lockDuration}),
            allocation
        );

        uint256 timestamp = bound(_timestamp, lock.startTime, lock.cliff - 1);
        uint256 unlockedAt = lock.unlockedAt(timestamp);
        assertEq(unlockedAt, 0, "unlockedAt");
    }

    modifier whenTimestampIsFromCliffUpToEndTime() {
        _;
    }

    function test_WhenTimestampEqualsCliff(uint256 _allocation, uint256 _cliffDuration, uint256 _lockDuration)
        external
        view
        whenTimestampIsFromCliffUpToEndTime
    {
        // it returns the amount unlocked at cliff

        uint256 allocation = bound(_allocation, 1, type(uint128).max);
        uint256 lockDuration = bound(_lockDuration, 1, type(uint32).max);
        uint256 cliffDuration = bound(_cliffDuration, 0, lockDuration);

        Lock memory lock = LockLib.createLock(
            LockParams({startTime: block.timestamp, cliffDuration: cliffDuration, lockDuration: lockDuration}),
            allocation
        );

        uint256 timestamp = lock.cliff;
        uint256 unlockedAt = lock.unlockedAt(timestamp);
        assertEq(unlockedAt, allocation * cliffDuration / lockDuration, "unlockedAt");
    }

    function test_WhenTimestampIsBetweenCliffAndEndTime(
        uint256 _duration,
        uint256 _allocation,
        uint256 _cliffDuration,
        uint256 _lockDuration
    ) external view whenTimestampIsFromCliffUpToEndTime {
        // it returns the linear unlocked amount

        uint256 allocation = bound(_allocation, 1, type(uint128).max);
        uint256 lockDuration = bound(_lockDuration, 1, type(uint32).max);
        uint256 cliffDuration = bound(_cliffDuration, 0, lockDuration);

        Lock memory lock = LockLib.createLock(
            LockParams({startTime: block.timestamp, cliffDuration: cliffDuration, lockDuration: lockDuration}),
            allocation
        );

        uint256 duration = bound(_duration, cliffDuration, lockDuration);

        uint256 timestamp = lock.startTime + duration;
        uint256 unlockedAt = lock.unlockedAt(timestamp);
        assertEq(unlockedAt, allocation * duration / lockDuration, "unlockedAt");
    }
}
