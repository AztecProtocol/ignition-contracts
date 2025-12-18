// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {
    IATPFactory,
    ILATPCore,
    ATPFactoryNonces,
    Aztec,
    IMATP,
    LockParams,
    Lock,
    LATPStorage,
    RevokableParams,
    IATPCore,
    IRegistry,
    MilestoneId
} from "test/token-vaults/Importer.sol";

import {ATPFactoryNoncesBase} from "../AtpFactoryNoncesBase.sol";

contract CreateMATPNoncesTest is ATPFactoryNoncesBase {
    IRegistry internal registry;

    function setUp() public override {
        super.setUp();
        registry = atpFactory.getRegistry();
    }

    function test_WhenCallerNEQMinter(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IATPFactory.NotMinter.selector, _caller));
        atpFactory.createMATP(address(1), 100, MilestoneId.wrap(0));
    }

    function test_WhenCallerEQMinter() external {
        registry.addMilestone();

        address atpAddress = atpFactory.predictMATPAddress(address(1), 100, MilestoneId.wrap(0));

        vm.expectEmit(true, true, true, true, address(atpFactory));
        emit IATPFactory.ATPCreated(address(1), atpAddress, 100);
        IMATP atp = atpFactory.createMATP(address(1), 100, MilestoneId.wrap(0));

        assertEq(atp.getBeneficiary(), address(1));
        assertEq(atp.getAllocation(), 100);
        assertEq(MilestoneId.unwrap(atp.getMilestoneId()), 0);
        assertEq(atp.getIsRevoked(), false);
        assertEq(atp.getIsRevokable(), true);

        assertEq(aztec.balanceOf(address(atp)), 100);
    }

    function test_WhenAnATPWithRepeatedOwnerAndAmountIsCreated() external {
        // It uses a nonce from the nonce lib
        // it creates and initializes an ATP
        // it transfers _allocation of tokens to the ATP
        // it returns the ATP

        registry.addMilestone();

        address beneficiary = address(1);
        uint256 allocation = 100;
        MilestoneId milestoneId = MilestoneId.wrap(0);

        address atpAddress = atpFactory.predictMATPAddress(beneficiary, allocation, milestoneId);

        vm.expectEmit(true, true, true, true, address(atpFactory));
        emit IATPFactory.ATPCreated(beneficiary, atpAddress, allocation);
        IMATP atp = atpFactory.createMATP(beneficiary, allocation, milestoneId);

        assertEq(atp.getBeneficiary(), beneficiary);
        assertEq(atp.getAllocation(), allocation);
        assertEq(MilestoneId.unwrap(atp.getMilestoneId()), MilestoneId.unwrap(milestoneId));
        assertEq(atp.getIsRevoked(), false);
        assertEq(atp.getIsRevokable(), true);
        assertEq(aztec.balanceOf(address(atp)), allocation);

        // Create a second with the same parameters
        address atpAddress2 = atpFactory.predictMATPAddress(beneficiary, allocation, milestoneId);
        vm.expectEmit(true, true, true, true, address(atpFactory));
        emit IATPFactory.ATPCreated(beneficiary, atpAddress2, allocation);
        IMATP atp2 = atpFactory.createMATP(beneficiary, allocation, milestoneId);
        assertEq(address(atp2), atpAddress2);
        assertEq(atp2.getBeneficiary(), beneficiary);
        assertEq(atp2.getAllocation(), allocation);
        assertEq(MilestoneId.unwrap(atp2.getMilestoneId()), MilestoneId.unwrap(milestoneId));

        assertNotEq(address(atp), address(atp2));
    }
}
