// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {ATPNonWithdrawableStaker} from "src/staking/ATPNonWithdrawableStaker.sol";
import {IATPWithdrawableStaker} from "src/staking/interfaces/IATPWithdrawableStaker.sol";
import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";
import {IStaking} from "src/staking/rollup-system-interfaces/IStaking.sol";

/**
 * @title ATP Withdrawable Staker
 * @author Aztec-Labs
 * @notice An implementation of an ATP staker that allows for withdrawals from the rollup
 */
contract ATPWithdrawableStaker is IATPWithdrawableStaker, ATPNonWithdrawableStaker {
    constructor(IERC20 _stakingAsset, IRegistry _rollupRegistry, IStakingRegistry _stakingRegistry)
        ATPNonWithdrawableStaker(_stakingAsset, _rollupRegistry, _stakingRegistry)
    {}

    /**
     * @notice Initiate a withdrawal from the rollup
     *
     * @param _version - the version of the rollup the _attester is active on
     * @param _attester - the address of the attester on the rollup
     *
     * @dev Initiating a withdrawal will return funds to the _recipient address, which is set the ATP address
     */
    function initiateWithdraw(uint256 _version, address _attester)
        external
        override(IATPWithdrawableStaker)
        onlyOperator
    {
        address rollup = ROLLUP_REGISTRY.getRollup(_version);
        address atp = getATP();

        IStaking(rollup).initiateWithdraw(_attester, atp);
    }

    /**
     * @notice Finalize a withdrawal from the rollup
     * - Note on the rollup contract, anyone can call this - it just exists for completeness
     *
     * @param _version The version of the rollup the _attester is active on
     * @param _attester The address of the attester on the rollup
     *
     * @dev This function can be called by anyone on the rollup, and is not necessarily required to be called via the staker
     */
    function finalizeWithdraw(uint256 _version, address _attester) external virtual override(IATPWithdrawableStaker) {
        address rollup = ROLLUP_REGISTRY.getRollup(_version);
        IStaking(rollup).finaliseWithdraw(_attester);
    }
}
