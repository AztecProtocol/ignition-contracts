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

contract GetBeneficiaryTest is MATPTestBase {
    IMATP public atp;
    IERC20 public tokenInput;

    address internal revoker;
    address internal beneficiary;
    MilestoneId internal milestoneId;

    function setUp() public override(MATPTestBase) {
        super.setUp();

        milestoneId = registry.addMilestone();
        atp = atpFactory.createMATP(address(this), 1000e18, milestoneId);

        vm.label(address(atp), "LATP");

        revoker = atp.getRevoker();
        vm.label(revoker, "Revoker");

        beneficiary = address(this);
    }

    function test_WhenMilestoneFailed() external {
        registry.setMilestoneStatus(milestoneId, MilestoneStatus.Failed);

        assertEq(atp.getBeneficiary(), revoker);
    }

    function test_WhenMilestoneSucceeded() external {
        registry.setMilestoneStatus(milestoneId, MilestoneStatus.Succeeded);
        assertEq(atp.getBeneficiary(), beneficiary);
    }

    function test_WhenMilestonePending() external {
        assertEq(atp.getBeneficiary(), beneficiary);

        // If revoked, we the actual storage should also be updated.
        vm.prank(revoker);
        atp.revoke();

        assertEq(atp.getBeneficiary(), revoker);
    }
}
