// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";
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

contract Case6Test is MATPTestBase {
    // In this case, we have a pending milestone for long, and then finally the milestone succeeds.
    // With the caveat that the full allocation is staked from the start

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
    }

    function test_Case6() public {
        atp.updateStakerOperator(address(this));
        atp.upgradeStaker(fakeStakerVersion);
        atp.approveStaker(allocation);
        staker.stake(allocation);

        uint256 cliff = unlockStartTime + unlockCliffDuration;

        uint256 unlocked = help_computeUnlocked(atp, cliff - 1);
        assertEq(unlocked, 0, "unlocked");

        vm.warp(cliff - 1);
        assertEq(atp.getClaimable(), unlocked, "claimable");

        unlocked = help_computeUnlocked(atp, cliff);
        assertGt(unlocked, 0, "unlocked");

        vm.warp(cliff);
        assertEq(atp.getClaimable(), 0, "claimable 2");

        vm.warp(unlockStartTime + unlockLockDuration);

        assertEq(atp.getClaimable(), 0);
        assertEq(token.balanceOf(address(atp)), 0);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(staker.STAKING().staked(address(staker)), allocation, "staked");

        emit log_named_decimal_uint("balance(atp)     ", token.balanceOf(address(atp)), 18);
        emit log_named_decimal_uint("balance(this)    ", token.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("staked           ", staker.STAKING().staked(address(staker)), 18);

        registry.setMilestoneStatus(milestoneId, MilestoneStatus.Succeeded);

        assertEq(atp.getClaimable(), 0, "claimable");

        staker.unstake(allocation);
        atp.claim();

        assertEq(atp.getClaimable(), 0, "claimable");
        assertEq(token.balanceOf(address(atp)), 0, "atp");
        assertEq(token.balanceOf(address(this)), allocation, "this");

        emit log_named_decimal_uint("balance(atp)     ", token.balanceOf(address(atp)), 18);
        emit log_named_decimal_uint("balance(this)    ", token.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("staked           ", staker.STAKING().staked(address(staker)), 18);
    }
}
