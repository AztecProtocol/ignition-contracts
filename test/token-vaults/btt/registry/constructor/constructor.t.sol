// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {Registry, IRegistry, LockParams} from "test/token-vaults/Importer.sol";

contract ConstructorTest is Test {
    function test_WhenOwnerEQAddressZero() external {
        // it reverts
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new Registry({__owner: address(0), _unlockCliffDuration: 1, _unlockLockDuration: 2});
    }

    modifier whenOwnerNEQAddressZero() {
        _;
    }

    function test_WhenUnlockLockDurationEQ0() external whenOwnerNEQAddressZero {
        // it reverts

        vm.expectRevert(abi.encodeWithSelector(IRegistry.InvalidUnlockDuration.selector));
        new Registry({__owner: address(1), _unlockCliffDuration: 0, _unlockLockDuration: 0});
    }

    modifier whenUnlockLockDurationGT0() {
        _;
    }

    function test_WhenUnlockCliffDurationLTUnlockLockDuration()
        external
        whenOwnerNEQAddressZero
        whenUnlockLockDurationGT0
    {
        // it reverts
        vm.expectRevert(abi.encodeWithSelector(IRegistry.InvalidUnlockCliffDuration.selector));
        new Registry({__owner: address(1), _unlockCliffDuration: 2, _unlockLockDuration: 1});
    }

    function test_WhenUnlockLockDurationGTUnlockCliffDuration()
        external
        whenOwnerNEQAddressZero
        whenUnlockLockDurationGT0
    {
        // it updates the unlockCliffDuration
        // it updates the unlockLockDuration

        Registry registry = new Registry(address(1), 1, 2);
        assertEq(registry.owner(), address(1));

        uint256 start = registry.getUnlockStartTime();

        LockParams memory lockParams = registry.getGlobalLockParams();
        assertEq(lockParams.startTime, start);
        assertEq(lockParams.cliffDuration, 1);
        assertEq(lockParams.lockDuration, 2);
    }
}
