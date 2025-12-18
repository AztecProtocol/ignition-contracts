// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {MilestoneId} from "./../../Registry.sol";

import {IATPCore, IATPPeriphery} from "./../base/IATP.sol";

interface IMATPCore is IATPCore {
    error RevokedOrFailed();

    function initialize(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId) external;
}

interface IMATPPeriphery is IATPPeriphery {
    function getMilestoneId() external view returns (MilestoneId);
    function getIsRevoked() external view returns (bool);
}

interface IMATP is IMATPCore, IMATPPeriphery {}
