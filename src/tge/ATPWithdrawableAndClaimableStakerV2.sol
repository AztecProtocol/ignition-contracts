// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import { IStaking } from "@aztec/core/interfaces/IStaking.sol";
import { IGSE } from "@aztec/governance/GSE.sol";
import { ATPNonWithdrawableStaker } from "src/staking/ATPNonWithdrawableStaker.sol";
import { ATPWithdrawableAndClaimableStaker, IERC20, IRegistry, IStakingRegistry } from "src/staking/ATPWithdrawableAndClaimableStaker.sol";
import { ATPWithdrawableStaker } from "src/staking/ATPWithdrawableStaker.sol";
import { IATPNonWithdrawableStaker } from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import { IATPWithdrawableStaker } from "src/staking/interfaces/IATPWithdrawableStaker.sol";

contract ATPWithdrawableAndClaimableStakerV2 is ATPWithdrawableAndClaimableStaker {
    constructor(
        IERC20 _stakingAsset,
        IRegistry _rollupRegistry,
        IStakingRegistry _stakingRegistry,
        uint256 _withdrawalTimestamp
    ) ATPWithdrawableAndClaimableStaker(_stakingAsset, _rollupRegistry, _stakingRegistry, _withdrawalTimestamp) {}

    function finalizeWithdraw(uint256 _version, address _attester)
        external
        override(IATPWithdrawableStaker, ATPWithdrawableStaker)
    {
        address rollup = ROLLUP_REGISTRY.getRollup(_version);
        IStaking(rollup).finalizeWithdraw(_attester);
    }

    function delegate(uint256 _version, address _attester, address _delegatee)
        external
        override(IATPNonWithdrawableStaker, ATPNonWithdrawableStaker)
        onlyOperator
    {
        address rollup = ROLLUP_REGISTRY.getRollup(_version);
        IGSE gse = IGSE(IStaking(rollup).getGSE());

        address instance = rollup;

        // If the attester is not registered on the instance, expect the bonus
        // It might not be registered if it have exited, but in that case, it is delegating
        // 0 power, so essentially just a no-op at that point.
        if (!gse.isRegistered(instance, _attester)) {
            instance = gse.getBonusInstanceAddress();
        }

        gse.delegate(instance, _attester, _delegatee);
    }
}
