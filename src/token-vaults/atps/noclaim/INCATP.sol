// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {LockParams} from "./../../libraries/LockLib.sol";
import {IATPPeriphery} from "./../base/IATP.sol";

import {ILATPCore} from "./../linear/ILATP.sol";

struct NCATPStorage {
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

interface INCATPCore is ILATPCore {}

interface INCATPPeriphery is IATPPeriphery {
    function getStore() external view returns (NCATPStorage memory);
    function getRevokeBeneficiary() external view returns (address);
}

interface INCATP is INCATPCore, INCATPPeriphery {}
