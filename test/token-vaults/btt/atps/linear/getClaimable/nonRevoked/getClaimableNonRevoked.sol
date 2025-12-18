// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {LATPTestBase} from "test/token-vaults/latp_base.sol";
import {Math} from "@oz/utils/math/Math.sol";

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {LATP, ILATP, ILATPCore, ATPFactory, IRegistry, Aztec, LockParams, Lock, LockLib} from "test/token-vaults/Importer.sol";

abstract contract GetClaimableNonRevokedTest is LATPTestBase {
    ILATP internal atp;

    mapping(bytes32 => uint256) internal values;

    function setUp() public virtual override(LATPTestBase) {
        super.setUp();
        deploy();

        help_upgrade(atp, address(this));

        registry.setExecuteAllowedAt(0);
    }

    function deploy() internal virtual;

    function getEndtimes() internal view returns (uint256, uint256) {
        uint256 lockEnd = atp.getGlobalLock().endTime;
        uint256 accumulationEnd = atp.getAccumulationLock().endTime;

        if (lockEnd < accumulationEnd) {
            return (lockEnd, accumulationEnd);
        }

        return (accumulationEnd, lockEnd);
    }

    function getCliffs() internal view returns (uint256, uint256) {
        uint256 lockCliff = atp.getGlobalLock().cliff;
        uint256 accumulationCliff = atp.getAccumulationLock().cliff;

        if (lockCliff < accumulationCliff) {
            return (lockCliff, accumulationCliff);
        }

        return (accumulationCliff, lockCliff);
    }

    function test_WhenTheLocksHaveEnded(
        uint256 _used,
        uint256 _stakeTime,
        uint256 _endTime,
        uint256 _surplus,
        uint256 _recover
    ) external {
        (, uint256 lateEnd) = getEndtimes();

        uint256 allocation = atp.getAllocation();
        uint256 surplus = bound(_surplus, 0, 1000e18);
        deal(address(token), address(atp), token.balanceOf(address(atp)) + surplus);

        // The usage will be bounded by the allocation we got when we will be staking
        uint256 stakeTime = bound(_stakeTime, block.timestamp, lateEnd - 1);
        uint256 accumulated = help_computeAccumulated(atp, stakeTime);
        uint256 used = bound(_used, 0, accumulated);

        vm.warp(stakeTime);
        help_approve(atp, used);
        help_stake(atp, used);

        uint256 expectedClaimable = allocation + surplus - used;

        uint256 endTime = bound(_endTime, lateEnd, type(uint256).max);
        vm.warp(endTime);

        // Because we are going to wait until they have both ended, we are only limited by the actual balance
        // which will be what we accumulated minus what we use elsewhere.
        assertEq(atp.getClaimable(), expectedClaimable, "claimable");

        // If we can claim something, ensure that the act of claiming means that we will have 0 claimable after
        if (expectedClaimable > 0) {
            assertEq(atp.claim(), expectedClaimable, "claim");
            assertEq(atp.getClaimable(), 0, "claimable 2");
        }

        uint256 recover = bound(_recover, 0, used);

        if (recover > 0) {
            // If we used something, we will recover it and claim it.
            help_unstake(atp, recover);

            assertEq(atp.getClaimable(), recover, "claimable 3");
            assertEq(atp.claim(), recover, "claim 2");
            assertEq(atp.getClaimable(), 0, "claimable 4");
        }
    }

    function test_WhenTheLocksHaveNotEnded(
        uint256 _claim1,
        uint256 _used,
        uint256 _claim2,
        uint256 _surplus,
        uint256 _recover
    ) external {
        uint256 allocation = atp.getAllocation();
        (uint256 earlyEnd, uint256 lateEnd) = getEndtimes();

        uint256 claim1 = bound(_claim1, block.timestamp, earlyEnd - 100);
        uint256 claim2 = bound(_claim2, claim1 + 1, lateEnd - 1);

        values["unlocked_1"] = help_computeUnlocked(atp, claim1);

        values["accumulated_1"] = help_computeAccumulated(atp, claim1);
        values["accumulated_2"] = help_computeAccumulated(atp, claim2);

        values["debt_1"] = allocation - values["accumulated_1"];
        values["debt_2"] = allocation - values["accumulated_2"];

        // 0. Adds a surplus to ensure that airdropping won't break the claimable
        uint256 surplus = bound(_surplus, 0, 1000e18);

        // 1. Initial balance, should be GE allocation
        values["balances_0"] = allocation + surplus;
        assertGe(values["balances_0"], allocation, "balance >= allocation");

        // 2.   We draw a random value up to the accumulated value p surplus that we use for staking
        uint256 used = bound(_used, 0, values["accumulated_1"] + surplus);
        assertEq(
            values["balances_0"] - values["debt_1"],
            values["accumulated_1"] + surplus,
            "balances - debt = accumulated + surplus"
        );
        values["balances_1"] = values["balances_0"] - used;

        // 3.   We compute the claimable value for time `claim_1`
        //      As we are not revokable, we are bounded by the effective balance as we must be able to cover the debt
        values["effective_balance_1"] = values["balances_1"] - values["debt_1"];
        values["expected_claimable_1"] = Math.min(values["effective_balance_1"], values["unlocked_1"]);

        // 4.   We claim the claimable, and reduce our balance (ensure that claimable is 0 right after claim)
        values["balances_2"] = values["balances_1"] - values["expected_claimable_1"];

        // 5.   We compute the claimable value for time `claim_2`
        values["effective_balance_2"] = values["balances_2"] - values["debt_2"];
        // The value unlocked at this point depends on if the global lock have ended or not.
        // If the global lock has ended, we should not be bound by the unlock, and we set the value to max.
        values["unlocked_2"] = atp.getGlobalLock().endTime <= claim2
            ? type(uint256).max
            : help_computeUnlocked(atp, claim2) - values["expected_claimable_1"];

        values["expected_claimable_2"] = Math.min(values["effective_balance_2"], values["unlocked_2"]);

        // Recover the used assets
        // 6.   We recover the used assets, and compute the claimable value for time `claim_2` now that we have more assets
        uint256 recover = bound(_recover, 0, used);
        values["balances_3"] = values["balances_2"] + recover;
        values["effective_balance_3"] = values["balances_3"] - values["debt_2"];
        values["expected_claimable_3"] = Math.min(values["effective_balance_3"], values["unlocked_2"]);

        // 7.   We claim the claimable, and reduce our balance (ensure that claimable is 0 right after claim
        values["balances_4"] = values["balances_3"] - values["expected_claimable_3"];

        ////////////////////////////////////////////////////////////////
        // Execute the scenario and check against the expected values //
        ////////////////////////////////////////////////////////////////

        // 0.
        deal(address(token), address(atp), token.balanceOf(address(atp)) + surplus);

        // 1.
        assertEq(token.balanceOf(address(atp)), values["balances_0"], "balance 1");
        vm.warp(claim1);

        // 2.
        assertEq(values["accumulated_1"] + surplus, atp.getStakeableAmount(), "stakeable = accumulated + surplus");
        help_approve(atp, used);
        help_stake(atp, used);

        // 3.
        assertEq(values["debt_1"], atp.getRevokableAmount(), "debt 1 = revokable");
        assertEq(values["effective_balance_1"], atp.getStakeableAmount(), "effective balance 1 = stakeable");
        assertEq(atp.getClaimable(), values["expected_claimable_1"], "claimable 1");

        // 4.
        if (values["expected_claimable_1"] > 0) {
            assertEq(atp.claim(), values["expected_claimable_1"], "claim of claimable 1");
            assertEq(atp.getClaimable(), 0, "claimable 2");
        }
        assertEq(token.balanceOf(address(atp)), values["balances_2"], "balance 2");

        // 5.
        vm.warp(claim2);
        assertEq(values["debt_2"], atp.getRevokableAmount(), "debt 2 = revokable");
        assertEq(values["effective_balance_2"], atp.getStakeableAmount(), "effective balance 2 = stakeable");
        assertEq(atp.getClaimable(), values["expected_claimable_2"], "claimable 3");

        // 6.
        help_unstake(atp, recover);
        assertEq(atp.getClaimable(), values["expected_claimable_3"], "claimable 4");
        assertEq(values["debt_2"], atp.getRevokableAmount(), "debt 2 = revokable");
        assertEq(values["effective_balance_3"], atp.getStakeableAmount(), "effective balance 3 = stakeable");

        // 7.
        if (values["expected_claimable_3"] > 0) {
            assertEq(atp.claim(), values["expected_claimable_3"], "claim of claimable 3");
            assertEq(atp.getClaimable(), 0, "claimable 5");
        }

        // At last we make sure that the lock has not ended yet.
        assertLt(block.timestamp, lateEnd, "locks have ended");
    }
}
