// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {Registry, IRegistry, LockParams, MilestoneId, MilestoneStatus} from "test/token-vaults/Importer.sol";

contract SetMilestoneStatusTest is Test {
    IRegistry internal registry;

    function setUp() public {
        registry = IRegistry(new Registry(address(this), 1, 2));
        registry.addMilestone();
    }

    function test() external {}

    function test_WhenCallerNeqOwner(address _caller) external {
        vm.assume(_caller != address(this));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        registry.setMilestoneStatus(MilestoneId.wrap(0), MilestoneStatus.Failed);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        registry.setMilestoneStatus(MilestoneId.wrap(0), MilestoneStatus.Succeeded);
    }

    modifier whenCallerEqOwner() {
        _;
    }

    function test_GivenStatusNeqPending(uint256 _status) external whenCallerEqOwner {
        MilestoneStatus status = MilestoneStatus(bound(_status, 1, 2));
        vm.assume(status != MilestoneStatus.Pending);
        registry.setMilestoneStatus(MilestoneId.wrap(0), status);

        vm.expectRevert(abi.encodeWithSelector(IRegistry.InvalidMilestoneStatus.selector, MilestoneId.wrap(0)));
        registry.setMilestoneStatus(MilestoneId.wrap(0), status);
    }

    function test_GivenMilestoneNotExists(uint256 _status) external whenCallerEqOwner {
        MilestoneStatus status = MilestoneStatus(bound(_status, 1, 2));
        MilestoneId id = MilestoneId.wrap(1);

        vm.expectRevert(abi.encodeWithSelector(IRegistry.InvalidMilestoneId.selector, id));
        registry.setMilestoneStatus(id, status);
    }

    modifier givenStatusEqPending() {
        vm.assume(registry.getMilestoneStatus(MilestoneId.wrap(0)) == MilestoneStatus.Pending);
        _;
    }

    function test_WhenNewStatusEqPending() external whenCallerEqOwner givenStatusEqPending {
        vm.expectRevert(abi.encodeWithSelector(IRegistry.InvalidMilestoneStatus.selector, MilestoneId.wrap(0)));
        registry.setMilestoneStatus(MilestoneId.wrap(0), MilestoneStatus.Pending);
    }

    function test_WhenNewStatusNeqPending(uint256 _status) external whenCallerEqOwner givenStatusEqPending {
        MilestoneStatus status = MilestoneStatus(bound(_status, 1, 2));
        vm.assume(status != MilestoneStatus.Pending);

        assertTrue(registry.getMilestoneStatus(MilestoneId.wrap(0)) == MilestoneStatus.Pending);

        vm.expectEmit(true, true, true, true, address(registry));
        emit IRegistry.MilestoneStatusUpdated(MilestoneId.wrap(0), status);
        registry.setMilestoneStatus(MilestoneId.wrap(0), status);

        assertTrue(registry.getMilestoneStatus(MilestoneId.wrap(0)) == status);
    }
}
