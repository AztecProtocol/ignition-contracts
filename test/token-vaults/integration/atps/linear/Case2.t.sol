// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {LATPTestBase} from "test/token-vaults/latp_base.sol";

import {Math} from "@oz/utils/math/Math.sol";
import {Strings} from "@oz/utils/Strings.sol";

import {LATP, ILATP, LockParams, Lock, LockLib, RevokableParams} from "test/token-vaults/Importer.sol";

contract Case2Test is LATPTestBase {
    // The case is close to the simplest user case, but with a revoke.
    // We assume that the global schedule is starting now, have a cliff of 52 weeks, and a lock duration of 104 weeks.
    // Then we have a user, that does nothing with the assets beyond claiming once every 4 weeks when possible until the LATP is depleted
    // but this time, the user is revoked reducing his allocation.

    ILATP internal atp;
    uint256 internal allocation = 1000e18;
    address internal revoker;

    LockParams accumulationLockParams;

    function setUp() public override {
        unlockStartTime = 1735689600; // 1st of January 2025
        unlockCliffDuration = 52 weeks;
        unlockLockDuration = 104 weeks;

        super.setUp();

        accumulationLockParams = LockParams({
            startTime: 1704067200, // 1st of January 2024
            cliffDuration: 52 weeks, // 1 year
            lockDuration: 208 weeks // 4 years
        });
    }

    function test_Case2_BeforeAllocationCliff() public {
        // Emulate an employee that have an accumulation lock of 4 years, with a cliff of 1 year.
        // The employee started working on the 1st of January 2024, so that is marked as the `startTime`.
        uint256 revokeTime = accumulationLockParams.startTime + 26 weeks;

        _case2(revokeTime);
    }

    function test_Case2_AfterAllocationCliff() public {
        // Emulate an employee that have an accumulation lock of 4 years, with a cliff of 1 year.
        // The employee started working on the 1st of January 2024, so that is marked as the `startTime`.
        uint256 revokeTime = accumulationLockParams.startTime + accumulationLockParams.cliffDuration + 26 weeks;

        _case2(revokeTime);
    }

    function _case2(uint256 _revokeTime) public {
        // Emulate an employee that have an accumulation lock of 4 years, with a cliff of 1 year.
        // The employee started working on the 1st of January 2024, so that is marked as the `startTime`.

        atp = atpFactory.createLATP(
            address(this),
            allocation,
            RevokableParams({revokeBeneficiary: revokeBeneficiary, lockParams: accumulationLockParams})
        );

        revoker = atp.getRevoker();

        uint256 unlocked = help_computeUnlocked(atp, _revokeTime);
        uint256 accumulated = help_computeAccumulated(atp, _revokeTime);

        assertEq(unlocked, 0);

        if (_revokeTime > accumulationLockParams.startTime + accumulationLockParams.cliffDuration) {
            assertGt(accumulated, unlocked); // The user have some accumulated funds, as we are PAST his cliff
        }

        vm.warp(_revokeTime);
        vm.prank(revoker);
        uint256 revokeAmount = atp.revoke();
        assertEq(revokeAmount, allocation - accumulated);
        emit log_named_uint(
            "Revoked at employment week ", (block.timestamp - accumulationLockParams.startTime) / 1 weeks
        );
        emit log_named_decimal_uint(
            string.concat(
                "Accumulated by week ", Strings.toString((block.timestamp - accumulationLockParams.startTime) / 1 weeks)
            ),
            accumulated,
            18
        );
        emit log_named_decimal_uint(
            string.concat(
                "Claimable by week ", Strings.toString((block.timestamp - accumulationLockParams.startTime) / 1 weeks)
            ),
            atp.getClaimable(),
            18
        );

        uint256 unlockCliff = unlockStartTime + unlockCliffDuration;

        unlocked = help_computeUnlocked(atp, unlockCliff - 1);

        assertEq(unlocked, 0);

        vm.warp(unlockCliff - 1);
        assertEq(atp.getClaimable(), unlocked);

        unlocked = help_computeUnlocked(atp, unlockCliff);
        assertGt(unlocked, 0);

        vm.warp(unlockCliff);
        assertEq(atp.getClaimable(), accumulated, "claimable REH");

        uint256 claimed = 0;

        // Like clockwork, we claim every 4 weeks on the spot until the LATP is depleted
        while (token.balanceOf(address(atp)) > 0) {
            unlocked = help_computeUnlocked(atp, block.timestamp) - claimed;

            uint256 debt = allocation - accumulated;
            uint256 effectiveBalance = allocation - debt - claimed;

            // Ensure that there are funds enough for the potential revoke.
            uint256 expectedClaimable = Math.min(effectiveBalance, unlocked);
            assertEq(atp.getClaimable(), expectedClaimable, "claimable loop");

            uint256 amount = atp.claim();
            assertEq(amount, expectedClaimable, "claim");
            claimed += amount;

            uint256 weekNumber = (block.timestamp - unlockStartTime) / 1 weeks;
            emit log_named_decimal_uint(
                string.concat("Total claimed by week ", Strings.toString(weekNumber)), claimed, 18
            );
            emit log_named_decimal_uint(
                string.concat("      claimed in week ", Strings.toString(weekNumber)), expectedClaimable, 18
            );

            // Progress time by 4 weeks
            vm.warp(block.timestamp + 4 weeks);
        }

        assertEq(atp.getClaimable(), 0);
        assertEq(token.balanceOf(address(atp)), 0);
        assertEq(token.balanceOf(revokeBeneficiary), revokeAmount, "a");
        assertEq(token.balanceOf(address(this)), allocation - revokeAmount, "b");

        emit log_named_decimal_uint("balance(atp)     ", token.balanceOf(address(atp)), 18);
        emit log_named_decimal_uint("balance(revoker) ", token.balanceOf(revokeBeneficiary), 18);
        emit log_named_decimal_uint("balance(this)    ", token.balanceOf(address(this)), 18);
    }
}
