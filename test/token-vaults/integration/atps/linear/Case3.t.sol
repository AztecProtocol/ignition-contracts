// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {LATPTestBase} from "test/token-vaults/latp_base.sol";
import {Math} from "@oz/utils/math/Math.sol";
import {Strings} from "@oz/utils/Strings.sol";

import {LATP, ILATP, LockParams, Lock, LockLib, RevokableParams} from "test/token-vaults/Importer.sol";

contract Case3Test is LATPTestBase {
    // We assume that the global schedule is starting now, have a cliff of 52 weeks, and a lock duration of 104 weeks.
    // In this case, the user strive to maximize their impact, they will exit funds as it becomes possible,
    // and use all non-revokable funds in staking as possible.

    ILATP internal atp;
    uint256 internal allocation = 1000e18;

    function setUp() public override {
        unlockStartTime = 1735689600; // 1st of January 2025
        unlockCliffDuration = 52 weeks;
        unlockLockDuration = 104 weeks;

        super.setUp();

        // Open up so we can stake
        registry.setExecuteAllowedAt(0);
    }

    function test_Case3_NonRevokable() public {
        atp = atpFactory.createLATP(
            address(this), allocation, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
        );
        vm.label(address(atp), "atp");

        help_upgrade(atp, address(this));

        assertEq(token.balanceOf(address(this)), 0, "balance");

        // We start
        help_approve(atp, allocation);
        help_stake(atp, allocation);

        uint256 cliff = unlockStartTime + unlockCliffDuration;
        uint256 endTime = unlockStartTime + unlockLockDuration;

        uint256 unlocked = help_computeUnlocked(atp, cliff - 1);
        assertEq(unlocked, 0, "unlocked");

        vm.warp(cliff - 1);
        assertEq(atp.getClaimable(), 0, "claimable 1");

        unlocked = help_computeUnlocked(atp, cliff);
        assertGt(unlocked, 0, "unlocked");

        vm.warp(cliff);
        // Normally we should have something claimable here, but we are staking it ALL
        // right now. As you will see in a few lines below, we can unstake it and then
        // claimable increases!
        assertEq(atp.getClaimable(), 0, "claimable 2");

        uint256 claimed = 0;

        while (block.timestamp <= endTime) {
            uint256 expectedClaimable = help_computeUnlocked(atp, block.timestamp) - claimed;

            // We mint 100 basis points of the staked amount as reward ever month
            help_mintReward(atp, Math.mulDiv(help_getStaked(atp), 100, 10000));

            // We unstake the enough staked to claim.
            // assuming instant unstaking here
            help_unstake(atp, expectedClaimable);

            assertEq(atp.getClaimable(), expectedClaimable, "claimable");

            uint256 amount = atp.claim();
            assertEq(amount, expectedClaimable, "claim");
            claimed += amount;

            _log(atp, expectedClaimable, claimed);

            // Progress time by 4 weeks
            vm.warp(block.timestamp + 4 weeks);
        }

        assertEq(atp.getClaimable(), 0, "claimable");

        assertEq(token.balanceOf(address(atp)), 0, "balance atp");
        assertEq(token.balanceOf(address(this)), allocation, "balance this");

        // We have claimed the allocation, but would like to still get the remainder, so we will be
        uint256 rewards = help_getRewards(atp);
        help_claimRewards(atp);

        assertEq(token.balanceOf(address(atp)), rewards, "balance");
        assertEq(token.balanceOf(address(this)), allocation, "balance 2");

        atp.claim();

        assertEq(token.balanceOf(address(atp)), 0, "balance");
        assertEq(token.balanceOf(address(this)), allocation + rewards, "balance 3");

        emit log_named_decimal_uint("Total claimed by beneficiary", token.balanceOf(address(this)), 18);
    }

    function test_Case3_Accumulation() public {
        // Emulate an employee that have an accumulation lock of 4 years, with a cliff of 1 year.
        // The employee started working on the 1st of January 2023, so that is marked as the `startTime`.
        // We use an earlier start time to make sure that the accumulated value is well above the unlock for a long time
        // This way we can see that the user can use the funds while he wait for them to be claimable.
        // Since this guy can just stake it all initially, we are going to be a little lazy, and just have him
        // stake whatever is left after his claims.

        LockParams memory accumulationLockParams = LockParams({
            startTime: 1672532640, // 1st of January 2023
            cliffDuration: 52 weeks, // 1 year
            lockDuration: 208 weeks // 4 years
        });

        atp = atpFactory.createLATP(
            address(this),
            allocation,
            RevokableParams({revokeBeneficiary: revokeBeneficiary, lockParams: accumulationLockParams})
        );
        help_upgrade(atp, address(this));

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

        help_approve(atp, accumulated);
        help_stake(atp, accumulated);

        uint256 claimed = 0;

        // Like clockwork, we claim every 4 weeks on the spot until the LATP is depleted
        while (token.balanceOf(address(atp)) > 0) {
            // We mint 100 basis points of the staked amount as reward ever month
            help_mintReward(atp, Math.mulDiv(help_getStaked(atp), 100, 10000));

            unlocked = help_computeUnlocked(atp, block.timestamp) - claimed;
            accumulated = help_computeAccumulated(atp, block.timestamp);

            uint256 debt = allocation - accumulated;
            uint256 effectiveBalance = allocation - debt - claimed;

            uint256 expectedClaimable = Math.min(effectiveBalance, unlocked);
            uint256 toUnstake = expectedClaimable - atp.getClaimable();
            help_unstake(atp, toUnstake);

            assertEq(atp.getClaimable(), expectedClaimable, "claimable loop");

            uint256 amount = atp.claim();
            assertEq(amount, expectedClaimable, "claim");
            claimed += amount;

            _log(atp, expectedClaimable, claimed);

            // Progress time by 4 weeks
            vm.warp(block.timestamp + 4 weeks);
        }

        assertEq(atp.getClaimable(), 0, "claimable");
    }

    function _log(ILATP _atp, uint256 _claimable, uint256 _claimed) internal {
        bool isRevokable = _atp.getIsRevokable();
        uint256 weekNumber = (block.timestamp - unlockStartTime) / 1 weeks;
        uint256 unlocked = help_computeUnlocked(_atp, block.timestamp);
        uint256 accumulated = isRevokable ? help_computeAccumulated(_atp, block.timestamp) : 0;
        string memory week = Strings.toString(weekNumber);
        emit log_named_decimal_uint(string.concat("Total claimed by week ", week), _claimed, 18);
        emit log_named_decimal_uint(string.concat("     unlocked by week ", week), unlocked, 18);
        if (isRevokable) {
            emit log_named_decimal_uint(string.concat("  accumulated by week ", week), accumulated, 18);
        }
        emit log_named_decimal_uint(string.concat("       staked in week ", week), help_getStaked(atp), 18);
        emit log_named_decimal_uint(string.concat("      claimed in week ", week), _claimable, 18);
        emit log_named_decimal_uint(string.concat("      rewards by week ", week), help_getRewards(atp), 18);
    }
}
