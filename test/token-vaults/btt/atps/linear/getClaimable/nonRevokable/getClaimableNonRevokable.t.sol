// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {LATPTestBase} from "test/token-vaults/latp_base.sol";
import {Math} from "@oz/utils/math/Math.sol";

import {ILATP, LockLib, RevokableParams} from "test/token-vaults/Importer.sol";

contract GetClaimableNonRevokableTest is LATPTestBase {
    ILATP internal atp;

    mapping(bytes32 => uint256) internal values;

    function setUp() public virtual override(LATPTestBase) {
        super.setUp();
        uint256 allocation = 100e18;

        registry.setExecuteAllowedAt(0);

        atp = atpFactory.createLATP(
            address(this), allocation, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
        );

        help_upgrade(atp, address(this));
    }

    function getEndtime() internal view returns (uint256) {
        return atp.getGlobalLock().endTime;
    }

    function getCliff() internal view returns (uint256) {
        return atp.getGlobalLock().cliff;
    }

    function test_WhenTheLocksHaveEnded(uint256 _used, uint256 _endTime, uint256 _surplus, uint256 _recover) external {
        uint256 allocation = atp.getAllocation();

        uint256 surplus = bound(_surplus, 0, 1000e18);
        deal(address(token), address(atp), token.balanceOf(address(atp)) + surplus);
        uint256 balance = token.balanceOf(address(atp));
        uint256 used = bound(_used, 0, balance);
        help_approve(atp, used);
        help_stake(atp, used);

        uint256 expectedClaimable = allocation + surplus - used;

        uint256 endTime = bound(_endTime, getEndtime(), type(uint256).max);
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
        uint256 endTime = getEndtime();

        uint256 claim1 = bound(_claim1, block.timestamp, endTime - 100);
        uint256 claim2 = bound(_claim2, claim1 + 1, endTime - 1);

        uint256 unlocked1 = help_computeUnlocked(atp, claim1);
        uint256 unlocked2 = help_computeUnlocked(atp, claim2);

        // 0. Adds a surplus to ensure that airdropping won't break the claimable
        uint256 surplus = bound(_surplus, 0, 1000e18);

        // 1. Initial balance, should be GE allocation
        values["balances_0"] = allocation + surplus;
        assertGe(values["balances_0"], allocation, "balance >= allocation");

        // 2.   We draw a random value that we want to use for staking
        //      Since we are non-revokable, we need not leave any funds in the contract.
        uint256 used = bound(_used, 0, values["balances_0"]);
        values["balances_1"] = values["balances_0"] - used;

        // 3.   We compute the claimable value for time `claim_1`
        // The `accumulated` will NEVER be the limiting factor as `lock.unlockedAt(currentTime) <= ALLOCATION`
        values["expected_claimable_1"] = Math.min(values["balances_1"], unlocked1);

        // 4.   We claim the claimable, and reduce our balance (ensure that claimable is 0 right after claim)
        values["balances_2"] = values["balances_1"] - values["expected_claimable_1"];

        // 5.   We compute the claimable value for time `claim_2`
        // The `accumulated` will NEVER be the limiting factor as `lock.unlockedAt(currentTime) - claimed <= ALLOCATION - claimed`
        values["expected_claimable_2"] = Math.min(values["balances_2"], unlocked2 - values["expected_claimable_1"]);

        // Recover the used assets
        // 6.   We emulate that we recover the used assets, and compute the claimable value for time `claim_2` now that we have more assets
        uint256 recover = bound(_recover, 0, used);
        values["balances_3"] = values["balances_2"] + recover;
        values["expected_claimable_3"] = Math.min(values["balances_3"], unlocked2 - values["expected_claimable_1"]);

        // 7.   We claim the claimable, and reduce our balance (ensure that claimable is 0 right after claim
        values["balances_4"] = values["balances_3"] - values["expected_claimable_3"];

        ////////////////////////////////////////////////////////////////
        // Execute the scenario and check against the expected values //
        ////////////////////////////////////////////////////////////////

        // 0.
        deal(address(token), address(atp), token.balanceOf(address(atp)) + surplus);

        // 1.
        assertEq(token.balanceOf(address(atp)), values["balances_0"], "balance");
        vm.warp(claim1);

        // 2.
        help_approve(atp, used);
        help_stake(atp, used);

        // 3.
        assertEq(atp.getClaimable(), values["expected_claimable_1"], "claimable 1");

        // 4.
        if (values["expected_claimable_1"] > 0) {
            assertEq(atp.claim(), values["expected_claimable_1"], "claim of claimable 1");
            assertEq(atp.getClaimable(), 0, "claimable 2");
        }
        assertEq(token.balanceOf(address(atp)), values["balances_2"], "balance");

        // 5.
        vm.warp(claim2);
        assertEq(atp.getClaimable(), values["expected_claimable_2"], "claimable 3");

        // 6.
        help_unstake(atp, recover);
        assertEq(atp.getClaimable(), values["expected_claimable_3"], "claimable 4");

        // 7.
        if (values["expected_claimable_3"] > 0) {
            assertEq(atp.claim(), values["expected_claimable_3"], "claim of claimable 3");
            assertEq(atp.getClaimable(), 0, "claimable 5");
        }

        // At last we make sure that the locks has not ended yet.
        assertLt(block.timestamp, endTime, "locks have ended");
    }
}
