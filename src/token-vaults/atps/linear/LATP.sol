// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {ATPType} from "./../base/IATP.sol";
import {ILATP, ILATPPeriphery, IATPPeriphery, LATPStorage} from "./ILATP.sol";
import {LATPCore, IERC20, IRegistry, IBaseStaker} from "./LATPCore.sol";

/**
 * @title   Linear Aztec Token Position
 * @notice  Linear Aztec Token Position with additional helper view functions
 *          This is a helper contract to make it easier to use the LATP contract
 *          Will not include any state mutating extensions, just easier access to the data
 *          I might be kinda strange doing this, but I just find it simpler when looking at the state mutating
 *          functions, as I don't need to skip functions etc.
 *
 *          It is also a neat way to make sure that all of the getters follow a similar pattern, as we like using
 *          different naming conventions for different types of data, e.g., constant vs mutable.
 */
contract LATP is ILATP, LATPCore {
    constructor(IRegistry _registry, IERC20 _token) LATPCore(_registry, _token) {}

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
        return store.isRevokable;
    }

    function getAllocation() external view override(IATPPeriphery) returns (uint256) {
        return allocation;
    }

    function getStore() external view override(ILATPPeriphery) returns (LATPStorage memory) {
        return store;
    }

    function getRevokeBeneficiary() external view override(ILATPPeriphery) returns (address) {
        return store.revokeBeneficiary;
    }

    function getType() external pure virtual override(IATPPeriphery) returns (ATPType) {
        return ATPType.Linear;
    }
}
