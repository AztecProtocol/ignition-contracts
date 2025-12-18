// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IATPWithdrawableStaker} from "./IATPWithdrawableStaker.sol";

/**
 * @title IATPWithdrawableAndClaimableStaker Interface
 * @author Aztec-Labs
 * @notice Interface for an ATP staker that allows for withdrawals from the rollup
 *         and enables ATP token holders to claim tokens only after staking has occurred
 */
interface IATPWithdrawableAndClaimableStaker is IATPWithdrawableStaker {
    /**
     * @notice Withdraw all available tokens to the beneficiary of the ATP
     * @dev Only callable if staking has occurred (withdrawable == true)
     * @dev Only callable by the operator
     *
     * Requirements:
     * - withdrawable must be true (staking must have occurred)
     * - Only operator can call this function
     */
    function withdrawAllTokensToBeneficiary() external;

    /**
     * @notice The timestamp at which withdrawals are enabled.
     */
    function WITHDRAWAL_TIMESTAMP() external view returns (uint256);

    /**
     * @notice Check if staking has occurred
     * @return bool indicating whether staking has occurred
     */
    function hasStaked() external view returns (bool);
}
