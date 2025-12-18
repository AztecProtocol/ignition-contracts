// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

/**
 * @notice  The parameters for a lock
 *          The parameters used to derive the actual lock.
 *
 * @param   startTime The timestamp that the lock starts at (0 before this value)
 * @param   cliffDuration Time until the cliff is reached
 * @param   lockDuration Time until the lock is fully unlocked
 */
struct LockParams {
    uint256 startTime;
    uint256 cliffDuration;
    uint256 lockDuration;
}

/**
 * @notice  The lock struct
 * @param   startTime The timestamp that the lock starts at (0 before this value)
 * @param   cliff The timestamp of the cliff of the lock (0 before this value, >= startTime)
 * @param   endTime The timestamp that the lock ends at, >= cliff
 * @param   allocation The amount of tokens that are locked
 */
struct Lock {
    uint256 startTime;
    uint256 cliff;
    uint256 endTime;
    uint256 allocation;
}

/**
 * @title   LockLib
 * @notice  Library for handling "locks" on assets
 *          A lock is in this case, a curve defining the amount available at any given timestamp.
 *          The particular lock is a linear curve with a cliff.
 */
library LockLib {
    error LockDurationMustBeGTZero();
    error LockDurationMustBeGECliffDuration(uint256 lockDuration, uint256 cliffDuration);

    /**
     * @notice  Check if the lock has ended
     *
     * @param _lock   The lock
     * @param _timestamp   The timestamp to check
     *
     * @return  True if the lock has ended
     */
    function hasEnded(Lock memory _lock, uint256 _timestamp) internal pure returns (bool) {
        return _timestamp >= _lock.endTime;
    }

    /**
     * @notice  Get the unlocked value of the lock at a given timestamp
     *
     * @param _lock   The lock
     * @param _timestamp   The timestamp to get the value at
     *
     * @return  The unlocked value at the given timestamp
     */
    function unlockedAt(Lock memory _lock, uint256 _timestamp) internal pure returns (uint256) {
        if (_timestamp < _lock.cliff) {
            return 0;
        }

        if (_timestamp >= _lock.endTime) {
            return _lock.allocation;
        }

        return (_lock.allocation * (_timestamp - _lock.startTime)) / (_lock.endTime - _lock.startTime);
    }

    /**
     * @notice  Create a lock
     *
     * @dev     The caller should make sure that `_allocation` is not zero
     *
     * @param _params   The lock params
     * @param _allocation   The allocation of the lock
     *
     * @return  The lock
     */
    function createLock(LockParams memory _params, uint256 _allocation) internal pure returns (Lock memory) {
        LockLib.assertValid(_params);
        return Lock({
            startTime: _params.startTime,
            cliff: _params.startTime + _params.cliffDuration,
            endTime: _params.startTime + _params.lockDuration,
            allocation: _allocation
        });
    }

    /**
     * @notice  Assert that the lock params are valid
     *
     * @param _params   The lock params
     */
    function assertValid(LockParams memory _params) internal pure {
        require(_params.lockDuration > 0, LockDurationMustBeGTZero());
        require(
            _params.lockDuration >= _params.cliffDuration,
            LockDurationMustBeGECliffDuration(_params.lockDuration, _params.cliffDuration)
        );
    }

    /**
     * @notice  Check if the lock params are empty
     *
     * @param _params   The lock params
     *
     * @return  True if the lock params are empty
     */
    function isEmpty(LockParams memory _params) internal pure returns (bool) {
        return _params.startTime == 0 && _params.cliffDuration == 0 && _params.lockDuration == 0;
    }

    /**
     * @notice  Get an empty lock params
     *
     * @return  An empty lock params
     */
    function empty() internal pure returns (LockParams memory) {
        return LockParams({startTime: 0, cliffDuration: 0, lockDuration: 0});
    }
}
