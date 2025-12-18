// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {MATPTestBase} from "test/token-vaults/matp_base.sol";

import {
    IMATP,
    IATPCore,
    IMATPCore,
    ATPFactory,
    LockParams,
    Lock,
    LockLib,
    RevokableParams,
    MilestoneId,
    MilestoneStatus
} from "test/token-vaults/Importer.sol";

contract UpdateStakerOperatorTest is MATPTestBase {
    IMATP public atp;
    IERC20 public tokenInput;

    address internal operator = address(bytes20("operator"));

    function setUp() public override(MATPTestBase) {
        super.setUp();

        MilestoneId milestoneId = registry.addMilestone();
        atp = atpFactory.createMATP(address(this), 1000e18, milestoneId);
    }

    function test_WhenCallerIsNotBeneficiary(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotBeneficiary.selector, _caller, address(this)));
        vm.prank(_caller);
        atp.updateStakerOperator(address(0xdead));
    }

    function test_whenRevoked() external {
        vm.prank(atp.getRevoker());
        atp.revoke();

        vm.prank(atp.getRevoker());
        vm.expectRevert(abi.encodeWithSelector(IMATPCore.RevokedOrFailed.selector));
        atp.updateStakerOperator(address(0xdead));
    }

    function test_whenFailed() external {
        registry.setMilestoneStatus(atp.getMilestoneId(), MilestoneStatus.Failed);

        vm.prank(atp.getRevoker());
        vm.expectRevert(abi.encodeWithSelector(IMATPCore.RevokedOrFailed.selector));
        atp.updateStakerOperator(address(0xdead));
    }

    function test_whenCallerIsBeneficiary() external {
        // it updates the operator

        vm.expectEmit(true, true, true, true, address(atp));
        emit IATPCore.StakerOperatorUpdated(address(0xdead));

        atp.updateStakerOperator(address(0xdead));

        assertEq(atp.getStaker().getOperator(), address(0xdead));
    }
}
