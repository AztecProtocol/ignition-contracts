// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {Registry, IRegistry, StakerVersion, BaseStaker} from "test/token-vaults/Importer.sol";

contract BadUUID {
    function proxiableUUID() external pure returns (bytes32) {
        return bytes32("don't open, dead inside");
    }

    function test() external {}
}

contract MilestoneStakerImplementationTest is Test {
    Registry public registry;

    function setUp() public {
        registry = new Registry({__owner: address(this), _unlockCliffDuration: 0, _unlockLockDuration: 1000});
    }

    function test_WhenCallerIsNotOwner(address _caller, address _implementation) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        registry.registerStakerImplementation(_implementation);

        assertEq(StakerVersion.unwrap(registry.getNextStakerVersion()), 1);
    }

    modifier whenCallerIsOwner() {
        _;
    }

    function test_WhenImplementationIsNotUUPSUpgradable(address _implementation) external whenCallerIsOwner {
        // it reverts

        vm.assume(_implementation != registry.getStakerImplementation(StakerVersion.wrap(0)));
        vm.expectRevert();
        registry.registerStakerImplementation(_implementation);

        // Or invalid proxiableUUID returned
        address _badUUID = address(new BadUUID());
        vm.expectRevert(abi.encodeWithSelector(IRegistry.InvalidStakerImplementation.selector, _badUUID));
        registry.registerStakerImplementation(_badUUID);
    }

    function test_WhenCallerIsOwner() external whenCallerIsOwner {
        // it registers the staker implementation
        // it emits a {StakerRegistered} event

        // Ensure that version 1 is not registered already.
        vm.expectRevert(abi.encodeWithSelector(IRegistry.UnRegisteredStaker.selector, StakerVersion.wrap(1)));
        registry.getStakerImplementation(StakerVersion.wrap(1));

        address _implementation = address(new BaseStaker());

        vm.expectEmit(true, true, true, true, address(registry));
        emit IRegistry.StakerRegistered(StakerVersion.wrap(1), _implementation);
        registry.registerStakerImplementation(_implementation);
        assertTrue(registry.getStakerImplementation(StakerVersion.wrap(1)) == _implementation);

        assertEq(StakerVersion.unwrap(registry.getNextStakerVersion()), 2);
    }
}
