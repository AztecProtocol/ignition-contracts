// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

/**
 * @title Governance Staking Escrow Minimal Interface
 * @author Aztec-Labs
 * @notice A minimal interface for the Governance Staking Escrow contract
 *
 * @dev includes only the function that are interacted with from the staker
 */
interface IGSE {
    function delegate(address _instance, address _attester, address _delegatee) external;
    function ACTIVATION_THRESHOLD() external view returns (uint256);
}
