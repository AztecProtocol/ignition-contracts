// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Address} from "@oz/utils/Address.sol";
import {Ownable} from "@oz/access/Ownable.sol";

interface IGovernanceAcceleratedLock {
    error GovernanceAcceleratedLock__LockTimeNotMet();
    error GovernanceAcceleratedLock__GovernanceAddressCannotBeZero();

    event LockAccelerated();
    event LockExtended();

    function lockAccelerated() external view returns (bool);
    function accelerateLock() external;
    function extendLock() external;
    function relay(address _target, bytes calldata _data) external returns (bytes memory);
}

contract GovernanceAcceleratedLock is Ownable, IGovernanceAcceleratedLock {
    /// @notice The start time of the lock
    uint256 public immutable START_TIME;

    /// @notice The extended lock time
    uint256 public constant EXTENDED_LOCK_TIME = 365 days;
    /// @notice The shorter lock time
    uint256 public constant SHORTER_LOCK_TIME = 90 days;

    /// @notice Whether the lock is currently accelerated
    bool public lockAccelerated = false;

    /**
     * @param _governance The address of the governance contract (Owner)
     * @param _startTime The start time of the lock
     */
    constructor(address _governance, uint256 _startTime) Ownable(_governance) {
        require(_governance != address(0), GovernanceAcceleratedLock__GovernanceAddressCannotBeZero());
        START_TIME = _startTime;
    }

    /**
     * @notice Accelerate the lock
     * @notice The lock can be decelerated by calling extendLock
     *
     * @dev Only the owner can accelerate the lock
     */
    function accelerateLock() external override(IGovernanceAcceleratedLock) onlyOwner {
        lockAccelerated = true;
        emit LockAccelerated();
    }

    /**
     * @notice Extend the lock
     * @notice The lock can be accelerated by calling accelerateLock
     *
     * @dev Only the owner can extend the lock
     */
    function extendLock() external override(IGovernanceAcceleratedLock) onlyOwner {
        lockAccelerated = false;
        emit LockExtended();
    }

    /**
     * @notice Relay a call to a target contract
     * @notice The call will be relayed if the lock is accelerated
     *
     * @dev The relay function CANNOT send native tokens (ETH)
     * @dev Only the owner can relay the call
     * 
     * @param _target The target contract to relay the call to
     * @param _data The data to relay to the target contract
     * @return The result of the call
     */
    function relay(address _target, bytes calldata _data)
        external
        override(IGovernanceAcceleratedLock)
        onlyOwner
        returns (bytes memory)
    {
        uint256 lockTime = lockAccelerated ? SHORTER_LOCK_TIME : EXTENDED_LOCK_TIME;
        require(block.timestamp >= START_TIME + lockTime, GovernanceAcceleratedLock__LockTimeNotMet());
        return Address.functionCall(_target, _data);
    }
}
