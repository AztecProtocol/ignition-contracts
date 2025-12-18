// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {MockERC20} from "test/forge-std/mocks/MockERC20.sol";
import {MATPTestBase} from "test/token-vaults/matp_base.sol";
import {Math} from "@oz/utils/math/Math.sol";
import {FakeStaker} from "test/token-vaults/mocks/FakeStaker.sol";

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

contract ClaimTest is MATPTestBase {
    IMATP public atp;
    IERC20 public tokenInput;

    address internal revoker;
    address internal beneficiary;
    MilestoneId internal milestoneId;
    FakeStaker internal staker;

    function setUp() public override(MATPTestBase) {
        super.setUp();

        registry.setExecuteAllowedAt(0);

        milestoneId = registry.addMilestone();
        atp = atpFactory.createMATP(address(this), 1000e18, milestoneId);

        vm.label(address(atp), "MATP");

        revoker = atp.getRevoker();
        vm.label(revoker, "Revoker");

        beneficiary = address(this);

        staker = FakeStaker(address(atp.getStaker()));
    }

    function test_WhenRevoked(uint256 _time, uint256 _staked) external {
        uint256 initialBalance = token.balanceOf(address(atp));
        // We don't claim it all, such that there is at least 1 left for the first claim by the
        // revoker. This is to avoid having an if for the case of 0 claimable.
        uint256 staked = bound(_staked, 1, initialBalance - 1);
        help_upgrade(atp);
        help_approve(atp, staked);
        help_stake(atp, staked);

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

        assertLt(atp.getClaimable(), initialBalance, "claimable");

        vm.prank(revoker);
        uint256 claimed = atp.claim();
        assertEq(atp.getClaimable(), 0, "claimable 1");
        assertEq(claimed, atp.getClaimed(), "claimed");
        assertEq(token.balanceOf(revoker), claimed, "balance");

        // The revoke operator can then go and unstake the funds to exit these as well

        address revokeOperator = registry.getRevokerOperator();
        vm.prank(revokeOperator);
        staker.unstake(staked);

        assertEq(atp.getClaimable(), initialBalance - claimed, "claimable 2");

        vm.prank(revoker);
        claimed += atp.claim();

        assertEq(atp.getClaimed(), claimed, "claimed 2");

        assertEq(token.balanceOf(revoker), initialBalance, "balance");
        assertEq(atp.getClaimable(), 0, "claimable 3");
    }

    modifier whenNotRevoked() {
        _;
    }

    function test_WhenPending(uint256 _time) public whenNotRevoked {
        uint256 endTime = atp.getGlobalLock().endTime;
        uint256 time = bound(_time, block.timestamp, endTime - 1);
        vm.warp(time);

        assertEq(atp.getClaimable(), 0);

        vm.expectRevert(abi.encodeWithSelector(IATPCore.NoClaimable.selector));
        atp.claim();
    }

    function test_WhenFailed(uint256 _time) public whenNotRevoked {
        registry.setMilestoneStatus(milestoneId, MilestoneStatus.Failed);
        address revoker = registry.getRevoker();

        uint256 endTime = atp.getGlobalLock().endTime;
        uint256 time = bound(_time, block.timestamp, endTime - 1);
        vm.warp(time);

        uint256 balance = token.balanceOf(address(atp));
        assertEq(atp.getClaimable(), balance);
        assertEq(token.balanceOf(revoker), 0);

        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotBeneficiary.selector, address(this), revoker));
        atp.claim();

        vm.prank(revoker);
        atp.claim();

        assertEq(token.balanceOf(revoker), balance);
    }

    modifier whenMilestoneSucceeded() {
        registry.setMilestoneStatus(milestoneId, MilestoneStatus.Succeeded);
        _;
    }

    function test_WhenNotStaking(uint256 _time) external whenNotRevoked whenMilestoneSucceeded {
        uint256 endTime = atp.getGlobalLock().endTime;
        uint256 cliff = atp.getGlobalLock().cliff;
        uint256 time = bound(_time, cliff, endTime - 100);
        vm.warp(time);

        uint256 claimed = 0;
        assertEq(atp.getClaimable(), help_computeUnlocked(atp, time));

        claimed = atp.claim();
        assertEq(atp.getClaimed(), claimed, "claimed");
        assertEq(atp.getClaimable(), help_computeUnlocked(atp, time) - claimed);

        vm.warp(bound(_time, block.timestamp + 1, endTime - 1));

        claimed += atp.claim();
        assertEq(atp.getClaimed(), claimed, "claimed");
        assertEq(atp.getClaimable(), help_computeUnlocked(atp, block.timestamp) - claimed);

        vm.warp(endTime);
        assertEq(atp.getClaimable(), token.balanceOf(address(atp)));
        assertGt(atp.getClaimed(), 0);
    }
}
