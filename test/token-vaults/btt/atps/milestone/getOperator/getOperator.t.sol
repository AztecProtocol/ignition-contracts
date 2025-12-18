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
    MilestoneStatus,
    IBaseStaker
} from "test/token-vaults/Importer.sol";

contract GetOperatorTest is MATPTestBase {
    IMATP public atp;
    IERC20 public tokenInput;

    IBaseStaker internal staker;
    address internal revokerOperator;
    address internal operator = address(bytes20("operator"));
    MilestoneId internal milestoneId;

    function setUp() public override(MATPTestBase) {
        super.setUp();

        milestoneId = registry.addMilestone();
        atp = atpFactory.createMATP(address(this), 1000e18, milestoneId);

        vm.label(address(atp), "MATP");
        staker = atp.getStaker();

        revokerOperator = registry.getRevokerOperator();

        atp.updateStakerOperator(operator);

        assertEq(staker.getOperator(), operator);
        assertEq(atp.getOperator(), operator);
    }

    function test_WhenMilestoneFailed() external {
        registry.setMilestoneStatus(milestoneId, MilestoneStatus.Failed);
        assertEq(atp.getOperator(), revokerOperator);
    }

    function test_WhenMilestoneSucceeded() external {
        registry.setMilestoneStatus(milestoneId, MilestoneStatus.Succeeded);
        assertEq(atp.getOperator(), operator);
    }

    function test_WhenMilestonePending() external {
        assertEq(atp.getOperator(), operator);

        // If revoked, we the actual storage should also be updated.
        address revoker = atp.getRevoker();
        vm.prank(revoker);
        atp.revoke();

        assertEq(atp.getOperator(), revokerOperator);
    }
}
