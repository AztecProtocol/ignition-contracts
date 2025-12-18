// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {LATPTestBase} from "test/token-vaults/latp_base.sol";

import {Math} from "@oz/utils/math/Math.sol";
import {Strings} from "@oz/utils/Strings.sol";

import {LATP, ILATP, LockParams, Lock, LockLib, RevokableParams} from "test/token-vaults/Importer.sol";

contract Case1Test is LATPTestBase {
    // The case is the simplest user case.
    // We assume that the global schedule is starting now, have a cliff of 52 weeks, and a lock duration of 104 weeks.
    // Then we have a user, that does nothing with the assets beyond claiming once every 4 weeks when possible until the LATP is depleted
    //
    // If looking at this to get understand of values, I can recommend running with `-vv` as it will be printing claimed amounts week by week.

    ILATP internal atp;
    uint256 internal allocation = 1000e18;

    function setUp() public override {
        unlockStartTime = 1735689600; // 1st of January 2025
        unlockCliffDuration = 52 weeks;
        unlockLockDuration = 104 weeks;

        super.setUp();
    }

    function test_Case1_NonRevokable() public {
        atp = atpFactory.createLATP(
            address(this), allocation, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
        );

        uint256 cliff = unlockStartTime + unlockCliffDuration;

        uint256 unlocked = help_computeUnlocked(atp, cliff - 1);
        assertEq(unlocked, 0, "unlocked");

        vm.warp(cliff - 1);
        assertEq(atp.getClaimable(), unlocked, "claimable");

        unlocked = help_computeUnlocked(atp, cliff);
        assertGt(unlocked, 0, "unlocked");

        vm.warp(cliff);
        assertEq(atp.getClaimable(), unlocked, "claimable");

        uint256 claimed = 0;

        // Like clockwork, we claim every 4 weeks on the spot. Will land PERFECTLY on the endTime.
        while (token.balanceOf(address(atp)) > 0) {
            uint256 expectedClaimable = help_computeUnlocked(atp, block.timestamp) - claimed;
            assertEq(atp.getClaimable(), expectedClaimable, "claimable");

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
        assertEq(token.balanceOf(address(this)), allocation);

        emit log_named_decimal_uint("balance(atp)     ", token.balanceOf(address(atp)), 18);
        emit log_named_decimal_uint("balance(this)    ", token.balanceOf(address(this)), 18);
    }

    function test_Case1_Accumulation() public {
        // Emulate an employee that have an accumulation lock of 4 years, with a cliff of 1 year.
        // The employee started working on the 1st of January 2024, so that is marked as the `startTime`.

        LockParams memory accumulationLockParams = LockParams({
            startTime: 1704067200, // 1st of January 2024
            cliffDuration: 52 weeks, // 1 year
            lockDuration: 208 weeks // 4 years
        });

        atp = atpFactory.createLATP(
            address(this),
            allocation,
            RevokableParams({revokeBeneficiary: revokeBeneficiary, lockParams: accumulationLockParams})
        );

        uint256 unlockCliff = unlockStartTime + unlockCliffDuration;

        uint256 unlocked = help_computeUnlocked(atp, unlockCliff - 1);
        uint256 accumulated = help_computeAccumulated(atp, unlockCliff - 1);

        assertEq(unlocked, 0);
        assertGt(accumulated, unlocked);

        vm.warp(unlockCliff - 1);
        assertEq(atp.getClaimable(), unlocked);

        unlocked = help_computeUnlocked(atp, unlockCliff);
        accumulated = help_computeAccumulated(atp, unlockCliff);

        assertGt(unlocked, 0);
        assertGt(accumulated, unlocked);

        vm.warp(unlockCliff);
        assertEq(atp.getClaimable(), unlocked, "claimable REH");

        uint256 claimed = 0;

        // Like clockwork, we claim every 4 weeks on the spot until the LATP is depleted
        while (token.balanceOf(address(atp)) > 0) {
            unlocked = help_computeUnlocked(atp, block.timestamp) - claimed;
            accumulated = help_computeAccumulated(atp, block.timestamp);

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
        assertEq(token.balanceOf(address(this)), allocation);

        emit log_named_decimal_uint("balance(atp)     ", token.balanceOf(address(atp)), 18);
        emit log_named_decimal_uint("balance(this)    ", token.balanceOf(address(this)), 18);
    }
}
