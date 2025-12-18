// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {Registry, IRegistry, LockParams, MilestoneId, MilestoneStatus} from "test/token-vaults/Importer.sol";

contract AddMilestoneTest is Test {
    IRegistry internal registry;

    function setUp() public {
        registry = IRegistry(new Registry(address(this), 1, 2));
    }

    function test() external {}

    function test_WhenCallerNeqOwner(address _caller) external {
        vm.assume(_caller != address(this));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        registry.addMilestone();
    }

    function test_WhenCallerEqOwner() external {
        assertEq(MilestoneId.unwrap(registry.getNextMilestoneId()), 0);

        vm.expectRevert(abi.encodeWithSelector(IRegistry.InvalidMilestoneId.selector, MilestoneId.wrap(0)));
        registry.getMilestoneStatus(MilestoneId.wrap(0));

        emit IRegistry.MilestoneAdded(MilestoneId.wrap(0));
        MilestoneId ret = registry.addMilestone();

        assertEq(MilestoneId.unwrap(ret), 0);
        assertEq(MilestoneId.unwrap(registry.getNextMilestoneId()), 1);

        assertTrue(registry.getMilestoneStatus(MilestoneId.wrap(0)) == MilestoneStatus.Pending);
    }
}
