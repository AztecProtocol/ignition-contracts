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
    MilestoneId,
    MilestoneStatus
} from "test/token-vaults/Importer.sol";

contract RevokeTest is MATPTestBase {
    IMATP public atp;
    IERC20 public tokenInput;

    address internal staker;
    address internal beneficiary;
    address internal operator;
    address internal revoker;
    MilestoneId internal milestoneId;

    function setUp() public override(MATPTestBase) {
        super.setUp();

        milestoneId = registry.addMilestone();
        atp = atpFactory.createMATP(address(this), 1000e18, milestoneId);
        vm.label(address(atp), "LATP");

        staker = address(atp.getStaker());
        vm.label(staker, "Staker");

        revoker = atp.getRevoker();
        vm.label(revoker, "Revoker");

        atp.updateStakerOperator(address(bytes20("operator")));
        operator = atp.getStaker().getOperator();
        vm.label(operator, "Operator");

        beneficiary = atp.getBeneficiary();
        vm.label(beneficiary, "Beneficiary");
    }

    function test_GivenAlreadyRevoked() external {
        // it reverts {AlreadyRevoked()}

        vm.prank(revoker);
        atp.revoke();

        vm.prank(revoker);
        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotRevokable.selector));
        atp.revoke();
    }

    modifier givenNotRevoked() {
        _;
    }

    function test_GivenMilestoneNotPending(uint256 _status) external givenNotRevoked {
        // it reverts {NotRevokable()}

        MilestoneStatus status = MilestoneStatus(bound(_status, 1, 2));
        vm.assume(status != MilestoneStatus.Pending);
        registry.setMilestoneStatus(milestoneId, status);

        vm.prank(revoker);
        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotRevokable.selector));
        atp.revoke();
    }

    modifier givenMilestonePending() {
        _;
    }

    function test_WhenCallerNEQRevoker(address _caller) external givenNotRevoked givenMilestonePending {
        // it reverts {NotRevoker()}

        vm.assume(_caller != revoker);
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotRevoker.selector, _caller, revoker));
        atp.revoke();
    }

    function test_WhenCallerEQRevoker() external givenNotRevoked givenMilestonePending {
        assertEq(atp.getBeneficiary(), beneficiary);
        assertEq(atp.getStaker().getOperator(), operator);

        uint256 allocation = atp.getAllocation();

        vm.prank(revoker);
        vm.expectEmit(true, true, true, true, address(atp));
        emit IATPCore.Revoked(allocation);
        uint256 revoked = atp.revoke();

        assertEq(revoked, allocation);

        assertEq(atp.getIsRevoked(), true);
        assertEq(atp.getIsRevokable(), false);

        assertNotEq(atp.getBeneficiary(), beneficiary);
        assertNotEq(atp.getStaker().getOperator(), operator);

        assertEq(atp.getBeneficiary(), revoker);
        assertEq(atp.getStaker().getOperator(), registry.getRevokerOperator());
    }
}
