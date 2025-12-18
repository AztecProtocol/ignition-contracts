// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

/**
 * @title Rollup Registry Minimal Interface
 * @author Aztec-Labs
 * @notice A minimal interface for the Rollup Registry contract
 *
 * @dev includes only the function that are interacted with from the staker
 */
interface IRegistry {
    function getCanonicalRollup() external view returns (address);
    function getRollup(uint256 _version) external view returns (address);
    function getGovernance() external view returns (address);
}
