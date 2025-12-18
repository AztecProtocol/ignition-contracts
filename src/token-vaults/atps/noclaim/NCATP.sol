// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {ATPType, IATPCore} from "./../base/IATP.sol";
import {LATP} from "./../linear/LATP.sol";
import {LATPCore, IERC20, IRegistry} from "./../linear/LATPCore.sol";

/**
 * @title   Non Claimable Linear Aztec Position
 * @notice  An override of the LATP contract to make it non-claimable.
 */
contract NCATP is LATP {

    constructor(IRegistry _registry, IERC20 _token) LATP(_registry, _token) {}

    function claim() external override(IATPCore, LATPCore) onlyBeneficiary returns (uint256) {
        revert NoClaimable();
    }

    function getType() external pure override(LATP) returns (ATPType) {
        return ATPType.NonClaim;
    }
}
