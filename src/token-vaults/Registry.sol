// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Ownable2Step, Ownable} from "@oz/access/Ownable2Step.sol";
import {UUPSUpgradeable, ERC1967Utils} from "@oz/proxy/utils/UUPSUpgradeable.sol";
import {LockParams} from "./libraries/LockLib.sol";
import {BaseStaker} from "./staker/BaseStaker.sol";

type MilestoneId is uint96;

type StakerVersion is uint256;

enum MilestoneStatus {
    Pending,
    Failed,
    Succeeded
}

interface IRegistry {
    event UpdatedRevoker(address revoker);
    event UpdatedRevokerOperator(address revokerOperator);
    event UpdatedExecuteAllowedAt(uint256 executeAllowedAt);
    event UpdatedUnlockStartTime(uint256 unlockStartTime);
    event StakerRegistered(StakerVersion version, address implementation);
    event MilestoneAdded(MilestoneId milestoneId);
    event MilestoneStatusUpdated(MilestoneId milestoneId, MilestoneStatus status);

    error InvalidExecuteAllowedAt(uint256 newExecuteAllowedAt, uint256 currentExecuteAllowedAt);
    error InvalidUnlockStartTime(uint256 newUnlockStartTime, uint256 currentUnlockStartTime);
    error InvalidUnlockDuration();
    error InvalidUnlockCliffDuration();
    error InvalidStakerImplementation(address implementation);

    error UnRegisteredStaker(StakerVersion version);
    error InvalidMilestoneId(MilestoneId milestoneId);
    error InvalidMilestoneStatus(MilestoneId milestoneId);

    function setRevoker(address _revoker) external;
    function setRevokerOperator(address _revokerOperator) external;
    function setExecuteAllowedAt(uint256 _executeAllowedAt) external;
    function setUnlockStartTime(uint256 _unlockStartTime) external;
    function registerStakerImplementation(address _implementation) external;
    function addMilestone() external returns (MilestoneId);
    function setMilestoneStatus(MilestoneId _milestoneId, MilestoneStatus _status) external;

    function getRevoker() external view returns (address);
    function getRevokerOperator() external view returns (address);
    function getExecuteAllowedAt() external view returns (uint256);
    function getUnlockStartTime() external view returns (uint256);
    function getGlobalLockParams() external view returns (LockParams memory);
    function getStakerImplementation(StakerVersion _version) external view returns (address);
    function getNextStakerVersion() external view returns (StakerVersion);
    function getMilestoneStatus(MilestoneId _milestoneId) external view returns (MilestoneStatus);
    function getNextMilestoneId() external view returns (MilestoneId);
}

contract Registry is Ownable2Step, IRegistry {
    uint256 internal immutable UNLOCK_CLIFF_DURATION;
    uint256 internal immutable UNLOCK_LOCK_DURATION;

    // @note An initial value set to be the unix timestamp of 1st of January 2027
    uint256 internal unlockStartTime = 1798761600;
    uint256 internal executeAllowedAt = 1798761600;
    address internal revoker;
    address internal revokerOperator;

    StakerVersion internal nextStakerVersion;
    mapping(StakerVersion version => address implementation) internal stakerImplementations;

    MilestoneId internal nextMilestoneId;
    mapping(MilestoneId milestoneId => MilestoneStatus status) internal milestones;

    constructor(address __owner, uint256 _unlockCliffDuration, uint256 _unlockLockDuration) Ownable(__owner) {
        require(_unlockLockDuration > 0, InvalidUnlockDuration());
        require(_unlockLockDuration >= _unlockCliffDuration, InvalidUnlockCliffDuration());

        UNLOCK_CLIFF_DURATION = _unlockCliffDuration;
        UNLOCK_LOCK_DURATION = _unlockLockDuration;

        // @note Register the base staker implementation
        stakerImplementations[StakerVersion.wrap(0)] = address(new BaseStaker());
        nextStakerVersion = StakerVersion.wrap(1);
    }

    /**
     * @notice  Add a new milestone
     *
     * @dev Only callable by the owner
     *
     * @return  The milestone id
     */
    function addMilestone() external override(IRegistry) onlyOwner returns (MilestoneId) {
        MilestoneId milestoneId = nextMilestoneId;
        nextMilestoneId = MilestoneId.wrap(MilestoneId.unwrap(nextMilestoneId) + 1);
        milestones[milestoneId] = MilestoneStatus.Pending; // To be explicit

        emit MilestoneAdded(milestoneId);
        return milestoneId;
    }

    function setMilestoneStatus(MilestoneId _milestoneId, MilestoneStatus _status)
        external
        override(IRegistry)
        onlyOwner
    {
        require(getMilestoneStatus(_milestoneId) == MilestoneStatus.Pending, InvalidMilestoneStatus(_milestoneId));
        require(_status != MilestoneStatus.Pending, InvalidMilestoneStatus(_milestoneId));
        milestones[_milestoneId] = _status;

        emit MilestoneStatusUpdated(_milestoneId, _status);
    }

    /**
     * @notice  Register a new staker implementation
     *
     * @dev Only callable by the owner
     *
     * @param _implementation   The address of the staker implementation
     */
    function registerStakerImplementation(address _implementation) external override(IRegistry) onlyOwner {
        require(
            UUPSUpgradeable(_implementation).proxiableUUID() == ERC1967Utils.IMPLEMENTATION_SLOT,
            InvalidStakerImplementation(_implementation)
        );

        StakerVersion version = nextStakerVersion;
        nextStakerVersion = StakerVersion.wrap(StakerVersion.unwrap(nextStakerVersion) + 1);
        stakerImplementations[version] = _implementation;

        emit StakerRegistered(version, _implementation);
    }

    /**
     * @notice  Set the revoker address
     *
     * @dev Only callable by the owner
     *
     * @param _revoker   The address of the revoker
     */
    function setRevoker(address _revoker) external override(IRegistry) onlyOwner {
        revoker = _revoker;
        emit UpdatedRevoker(_revoker);
    }

    function setRevokerOperator(address _revokerOperator) external override(IRegistry) onlyOwner {
        revokerOperator = _revokerOperator;
        emit UpdatedRevokerOperator(_revokerOperator);
    }

    /**
     * @notice  Set the execute allowed at timestamp
     *          Can only be decreased to avoid unintentional updates and give some guarantees to LATP beneficiaries
     *
     * @dev Only callable by the owner
     *
     * @param _executeAllowedAt   The timestamp of when the execute is allowed
     */
    function setExecuteAllowedAt(uint256 _executeAllowedAt) external override(IRegistry) onlyOwner {
        require(_executeAllowedAt < executeAllowedAt, InvalidExecuteAllowedAt(_executeAllowedAt, executeAllowedAt));
        executeAllowedAt = _executeAllowedAt;
        emit UpdatedExecuteAllowedAt(_executeAllowedAt);
    }

    /**
     * @notice  Set the unlock start time
     *          Can only be decreased to avoid unintentional updates and give some guarantees to LATP beneficiaries
     *
     * @dev Only callable by the owner
     *
     * @param _unlockStartTime   The timestamp of when the unlock starts
     */
    function setUnlockStartTime(uint256 _unlockStartTime) external override(IRegistry) onlyOwner {
        require(_unlockStartTime < unlockStartTime, InvalidUnlockStartTime(_unlockStartTime, unlockStartTime));
        unlockStartTime = _unlockStartTime;
        emit UpdatedUnlockStartTime(_unlockStartTime);
    }

    /**
     * @notice  Get the revoker address
     *
     * @return  The address of the revoker
     */
    function getRevoker() external view override(IRegistry) returns (address) {
        return revoker;
    }

    function getRevokerOperator() external view override(IRegistry) returns (address) {
        return revokerOperator;
    }

    /**
     * @notice  Get the execute allowed at timestamp
     *
     * @return  The timestamp of when the execute is allowed
     */
    function getExecuteAllowedAt() external view override(IRegistry) returns (uint256) {
        return executeAllowedAt;
    }

    /**
     * @notice  Get the unlock start time
     *
     * @return  The timestamp of when the unlock starts
     */
    function getUnlockStartTime() external view override(IRegistry) returns (uint256) {
        return unlockStartTime;
    }

    /**
     * @notice  Get the lock params for the global unlocking schedule
     *
     * @return  The global lock params
     */
    function getGlobalLockParams() external view override(IRegistry) returns (LockParams memory) {
        return LockParams({
            startTime: unlockStartTime, cliffDuration: UNLOCK_CLIFF_DURATION, lockDuration: UNLOCK_LOCK_DURATION
        });
    }

    /**
     * @notice  Get the implementation for a given staker version
     *
     * @param   _version   The version of the staker
     *
     * @return  The implementation for the given staker version
     */
    function getStakerImplementation(StakerVersion _version) external view override(IRegistry) returns (address) {
        require(StakerVersion.unwrap(_version) < StakerVersion.unwrap(nextStakerVersion), UnRegisteredStaker(_version));
        return stakerImplementations[_version];
    }

    /**
     * @notice  Get the next staker version
     *
     * @return  The next staker version
     */
    function getNextStakerVersion() external view override(IRegistry) returns (StakerVersion) {
        return nextStakerVersion;
    }

    function getNextMilestoneId() external view override(IRegistry) returns (MilestoneId) {
        return nextMilestoneId;
    }

    function getMilestoneStatus(MilestoneId _milestoneId) public view override(IRegistry) returns (MilestoneStatus) {
        require(
            MilestoneId.unwrap(_milestoneId) < MilestoneId.unwrap(nextMilestoneId), InvalidMilestoneId(_milestoneId)
        );
        return milestones[_milestoneId];
    }
}
