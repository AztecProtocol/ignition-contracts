// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Lock, LockParams} from "./../../libraries/LockLib.sol";
import {IATPCore, IATPPeriphery} from "./../base/IATP.sol";

struct LATPStorage {
    uint32 accumulationStartTime;
    uint32 accumulationCliffDuration;
    uint32 accumulationLockDuration;
    bool isRevokable;
    address revokeBeneficiary;
}

struct RevokableParams {
    address revokeBeneficiary;
    LockParams lockParams;
}

interface ILATPCore is IATPCore {
    error InsufficientStakeable(uint256 stakeable, uint256 allowance);
    error LockParamsMustBeEmpty();

    function initialize(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams) external;

    function getAccumulationLock() external view returns (Lock memory);
    function getRevokableAmount() external view returns (uint256);
    function getStakeableAmount() external view returns (uint256);
}

interface ILATPPeriphery is IATPPeriphery {
    function getStore() external view returns (LATPStorage memory);
    function getRevokeBeneficiary() external view returns (address);
}

interface ILATP is ILATPCore, ILATPPeriphery {}
