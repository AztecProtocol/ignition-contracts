// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IATPNonWithdrawableStaker} from "./IATPNonWithdrawableStaker.sol";

interface IATPWithdrawableStaker is IATPNonWithdrawableStaker {
    /**
     * @notice Initiate a withdrawal from the rollup
     *
     * @param _version - the rollup version to withdraw from
     * @param _attester - the address of the attester being withdrawn
     *
     * @dev This will revert if the staker is not the withdrawer
     */
    function initiateWithdraw(uint256 _version, address _attester) external;

    function finalizeWithdraw(uint256 _version, address _attester) external;
}
