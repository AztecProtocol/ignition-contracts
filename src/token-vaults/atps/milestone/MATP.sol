// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {ATPType} from "./../base/IATP.sol";
import {IMATP, IMATPPeriphery, IATPPeriphery} from "./IMATP.sol";
import {MATPCore, MilestoneId, IRegistry, IERC20, IBaseStaker} from "./MATPCore.sol";

contract MATP is IMATP, MATPCore {
    constructor(IRegistry _registry, IERC20 _token) MATPCore(_registry, _token) {}

    function getToken() external view override(IATPPeriphery) returns (IERC20) {
        return TOKEN;
    }

    function getRegistry() external view override(IATPPeriphery) returns (IRegistry) {
        return REGISTRY;
    }

    function getStaker() external view override(IATPPeriphery) returns (IBaseStaker) {
        return staker;
    }

    function getExecuteAllowedAt() external view override(IATPPeriphery) returns (uint256) {
        return REGISTRY.getExecuteAllowedAt();
    }

    function getClaimed() external view override(IATPPeriphery) returns (uint256) {
        return claimed;
    }

    function getRevoker() external view override(IATPPeriphery) returns (address) {
        return REGISTRY.getRevoker();
    }

    function getIsRevokable() external view override(IATPPeriphery) returns (bool) {
        return !isRevoked;
    }

    function getAllocation() external view override(IATPPeriphery) returns (uint256) {
        return allocation;
    }

    function getMilestoneId() external view override(IMATPPeriphery) returns (MilestoneId) {
        return milestoneId;
    }

    function getIsRevoked() external view override(IMATPPeriphery) returns (bool) {
        return isRevoked;
    }

    function getType() external pure override(IATPPeriphery) returns (ATPType) {
        return ATPType.Milestone;
    }
}
