// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {MockERC20} from "test/forge-std/mocks/MockERC20.sol";
import {MATPTestBase} from "test/token-vaults/matp_base.sol";
import {Math} from "@oz/utils/math/Math.sol";

import {
    LATP,
    IMATP,
    ILATPCore,
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

contract GetClaimableTest is MATPTestBase {
    IMATP public atp;
    IERC20 public tokenInput;

    address internal revoker;
    address internal beneficiary;
    MilestoneId internal milestoneId;

    function setUp() public override(MATPTestBase) {
        super.setUp();

        registry.setExecuteAllowedAt(0);

        milestoneId = registry.addMilestone();
        atp = atpFactory.createMATP(address(this), 1000e18, milestoneId);

        vm.label(address(atp), "LATP");

        revoker = atp.getRevoker();
        vm.label(revoker, "Revoker");

        beneficiary = address(this);
    }

    function test_WhenMilestoneFailed(uint256 _time) external {
        registry.setMilestoneStatus(milestoneId, MilestoneStatus.Failed);
        uint256 endTime = atp.getGlobalLock().endTime;
        uint256 time = bound(_time, block.timestamp, endTime + 1000);
        vm.warp(time);

        uint256 claimable = atp.getClaimable();
        assertEq(claimable, token.balanceOf(address(atp)));
    }

    function test_WhenMilestonePending(uint256 _time) external {
        uint256 endTime = atp.getGlobalLock().endTime;
        uint256 time = bound(_time, block.timestamp, endTime + 1000);
        vm.warp(time);

        uint256 claimable = atp.getClaimable();
        assertEq(claimable, 0);
    }

    function test_WhenRevoked(uint256 _time) external {
        uint256 endTime = atp.getGlobalLock().endTime;
        uint256 time = bound(_time, block.timestamp, endTime - 1);
        vm.warp(time);

        assertEq(atp.getClaimable(), 0);

        vm.prank(revoker);
        atp.revoke();

        assertEq(atp.getClaimable(), token.balanceOf(address(atp)));
        assertEq(atp.getIsRevoked(), true);
        assertEq(atp.getBeneficiary(), revoker);
        assertEq(atp.getOperator(), registry.getRevokerOperator());
    }

    modifier whenMilestoneSucceeded() {
        registry.setMilestoneStatus(milestoneId, MilestoneStatus.Succeeded);
        _;
    }

    function test_WhenNotStaking(uint256 _time) external whenMilestoneSucceeded {
        uint256 endTime = atp.getGlobalLock().endTime;
        uint256 time = bound(_time, block.timestamp, endTime - 1);
        vm.warp(time);

        {
            uint256 claimable = atp.getClaimable();
            uint256 unlocked = help_computeUnlocked(atp, time);
            assertEq(claimable, unlocked);
        }

        vm.warp(Math.max(block.timestamp, endTime + 1000));

        {
            uint256 claimable = atp.getClaimable();
            uint256 balance = token.balanceOf(address(atp));
            assertEq(claimable, balance);
        }
    }

    function test_WhenStaking(uint256 _time, uint256 _surplus, uint256 _staked, uint256 _recover)
        external
        whenMilestoneSucceeded
    {
        uint256 surplus = bound(_surplus, 0, 1000e18);
        deal(address(token), address(atp), token.balanceOf(address(atp)) + surplus);

        uint256 initialBalance = token.balanceOf(address(atp));
        uint256 staked = bound(_staked, 1, initialBalance);
        help_upgrade(atp);
        help_approve(atp, staked);
        help_stake(atp, staked);

        assertLt(token.balanceOf(address(atp)), initialBalance, "balance");

        uint256 endTime = atp.getGlobalLock().endTime;
        uint256 time = bound(_time, block.timestamp, endTime - 1);
        vm.warp(time);

        {
            uint256 unlocked = help_computeUnlocked(atp, time);
            uint256 balance = token.balanceOf(address(atp));
            assertEq(atp.getClaimable(), Math.min(balance, unlocked), "claimable");
        }

        vm.warp(Math.max(block.timestamp, endTime + 1000));

        assertEq(atp.getClaimable(), token.balanceOf(address(atp)), "claimable 2");

        uint256 tempBalance = token.balanceOf(address(atp));
        help_unstake(atp, bound(_recover, 1, staked));
        assertGt(token.balanceOf(address(atp)), tempBalance, "balance");

        assertEq(atp.getClaimable(), token.balanceOf(address(atp)), "claimable 3");
    }
}
