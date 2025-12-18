// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {
    IATPFactory,
    ILATPCore,
    ATPFactory,
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

import {ATPFactoryBase} from "../AtpFactoryBase.sol";

contract CreateMATPTest is ATPFactoryBase {
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
}
