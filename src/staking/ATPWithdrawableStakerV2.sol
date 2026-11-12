// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import {IStaking} from "@aztec/core/interfaces/IStaking.sol";
import {IGSE} from "@aztec/governance/GSE.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {ATPNonWithdrawableStaker} from "src/staking/ATPNonWithdrawableStaker.sol";
import {ATPWithdrawableStaker} from "src/staking/ATPWithdrawableStaker.sol";
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";

/**
 * @title ATP Withdrawable Staker V2
 * @author Aztec-Labs
 * @notice An implementation of an ATP staker that allows for withdrawals from the rollup.
 *         Carries the `finalizeWithdraw` and `delegate` fixes from `ATPWithdrawableAndClaimableStakerV2`,
 *         without the NCATP claim path, so funds can only ever return to the ATP.
 */
contract ATPWithdrawableStakerV2 is ATPWithdrawableStaker {
    constructor(IERC20 _stakingAsset, IRegistry _rollupRegistry, IStakingRegistry _stakingRegistry)
        ATPWithdrawableStaker(_stakingAsset, _rollupRegistry, _stakingRegistry)
    {}

    /**
     * @notice Finalize a withdrawal from the rollup
     *
     * @dev The V1 staker calls `finaliseWithdraw`, which does not exist on the deployed rollup
     *
     * @param _version The version of the rollup the _attester is active on
     * @param _attester The address of the attester on the rollup
     */
    function finalizeWithdraw(uint256 _version, address _attester) external override(ATPWithdrawableStaker) {
        address rollup = ROLLUP_REGISTRY.getRollup(_version);
        IStaking(rollup).finalizeWithdraw(_attester);
    }

    /**
     * @notice Delegate the voting power associated with an attester
     *
     * @dev Attesters deposited with `_moveWithLatestRollup` are registered on the bonus instance,
     *      not the rollup, so fall back to it when the attester is not registered on the rollup
     *
     * @param _version The version of the rollup to delegate to
     * @param _attester The address of the attester the voting power is associated with
     * @param _delegatee The address of the delegatee
     */
    function delegate(uint256 _version, address _attester, address _delegatee)
        external
        override(IATPNonWithdrawableStaker, ATPNonWithdrawableStaker)
        onlyOperator
    {
        address rollup = ROLLUP_REGISTRY.getRollup(_version);
        IGSE gse = IGSE(IStaking(rollup).getGSE());

        address instance = rollup;

        // If the attester has exited it is registered on neither, and delegating is a no-op
        if (!gse.isRegistered(instance, _attester)) {
            instance = gse.getBonusInstanceAddress();
        }

        gse.delegate(instance, _attester, _delegatee);
    }
}
