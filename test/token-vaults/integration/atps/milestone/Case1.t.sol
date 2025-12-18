// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {MockERC20} from "test/forge-std/mocks/MockERC20.sol";
import {MATPTestBase} from "test/token-vaults/matp_base.sol";
import {Math} from "@oz/utils/math/Math.sol";
import {FakeStaker} from "test/token-vaults/mocks/FakeStaker.sol";

import {Strings} from "@oz/utils/Strings.sol";

import {
    LATP,
    IMATP,
    IMATPCore,
    IATPCore,
    ATPFactory,
    Aztec,
    LockParams,
    Lock,
    LockLib,
    RevokableParams,
    MilestoneId,
    MilestoneStatus
} from "test/token-vaults/Importer.sol";

contract Case1Test is MATPTestBase {
    // The case is the simplest user case.
    // We assume that the global schedule is starting now, have a cliff of 52 weeks, and a lock duration of 104 weeks.
    // The milestone is succeeded.
    // Then we have a user, that does nothing with the assets beyond claiming once every 4 weeks when possible until the LATP is depleted
    //
    // If looking at this to get understand of values, I can recommend running with `-vv` as it will be printing claimed amounts week by week.

    IMATP public atp;
    IERC20 public tokenInput;

    address internal revoker;
    address internal beneficiary;
    MilestoneId internal milestoneId;
    FakeStaker internal staker;

    uint256 internal allocation = 1000e18;

    function setUp() public override(MATPTestBase) {
        unlockStartTime = 1735689600; // 1st of January 2025
        unlockCliffDuration = 52 weeks;
        unlockLockDuration = 104 weeks;

        super.setUp();

        registry.setExecuteAllowedAt(0);

        milestoneId = registry.addMilestone();
        atp = atpFactory.createMATP(address(this), allocation, milestoneId);

        vm.label(address(atp), "MATP");

        revoker = atp.getRevoker();
        vm.label(revoker, "Revoker");

        beneficiary = address(this);

        staker = FakeStaker(address(atp.getStaker()));

        registry.setMilestoneStatus(milestoneId, MilestoneStatus.Succeeded);
    }

    function test_Case1() public {
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
}
