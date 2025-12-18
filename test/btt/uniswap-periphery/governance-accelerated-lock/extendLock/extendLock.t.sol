// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {
    IGovernanceAcceleratedLock,
    GovernanceAcceleratedLock
} from "src/uniswap-periphery/GovernanceAcceleratedLock.sol";
import {Ownable} from "@oz/access/Ownable.sol";

import {Test} from "forge-std/Test.sol";

contract ExtendLockTest is Test {
    GovernanceAcceleratedLock public governanceAcceleratedLock;
    address public governance = makeAddr("governance");

    function setUp() external {
        governanceAcceleratedLock = new GovernanceAcceleratedLock(governance, block.timestamp + 1000);
    }

    function test_WhenCallerNEQOwner(address _caller) external {
        // it reverts with OnlyOwner

        vm.assume(_caller != governance);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        governanceAcceleratedLock.extendLock();
    }

    function test_WhenCallerEQOwner() external {
        // it emits LockExtended
        // it sets lockAccelerated to false

        vm.expectEmit(true, true, true, true, address(governanceAcceleratedLock));
        emit IGovernanceAcceleratedLock.LockExtended();
        vm.prank(governance);
        governanceAcceleratedLock.extendLock();

        assertFalse(governanceAcceleratedLock.lockAccelerated());
    }
}
