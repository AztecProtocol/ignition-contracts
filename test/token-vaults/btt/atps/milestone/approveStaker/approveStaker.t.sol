// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {MockERC20} from "test/forge-std/mocks/MockERC20.sol";
import {MATPTestBase} from "test/token-vaults/matp_base.sol";

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
    MilestoneId
} from "test/token-vaults/Importer.sol";

contract NonRevokedApproveStakerTest is MATPTestBase {
    IMATP public atp;
    IERC20 public tokenInput;

    address internal staker;

    function setUp() public override(MATPTestBase) {
        super.setUp();

        MilestoneId milestoneId = registry.addMilestone();
        atp = atpFactory.createMATP(address(this), 1000e18, milestoneId);

        vm.label(address(atp), "LATP");

        staker = address(atp.getStaker());
        vm.label(staker, "Staker");
    }

    function test_WhenCallerNEQBeneficiary(address _caller) external {
        // it reverts

        vm.assume(_caller != address(this));

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotBeneficiary.selector, _caller, address(this)));
        atp.approveStaker(100);
    }

    modifier whenCallerEQBeneficiary() {
        _;
    }

    function test_WhenTimeLTEXECUTE_ALLOWED_AT(uint256 _time) external whenCallerEQBeneficiary {
        // it reverts
        uint256 time = bound(_time, 0, atp.getExecuteAllowedAt() - 1);

        vm.warp(time);
        vm.expectRevert(
            abi.encodeWithSelector(IATPCore.ExecutionNotAllowedYet.selector, time, atp.getExecuteAllowedAt())
        );
        atp.approveStaker(100);
    }

    function test_whenTimeGEEXECUTE_ALLOWED_AT(uint256 _time, uint256 _amount) external whenCallerEQBeneficiary {
        // it updates allowance

        uint256 endTime = atp.getExecuteAllowedAt();
        uint256 time = bound(_time, endTime, endTime + 1000);
        vm.warp(time);

        assertEq(token.allowance(address(atp), staker), 0);

        vm.expectEmit(true, true, true, true, address(atp));
        emit IATPCore.ApprovedStaker(_amount);

        atp.approveStaker(_amount);

        assertEq(token.allowance(address(atp), staker), _amount);
    }
}
