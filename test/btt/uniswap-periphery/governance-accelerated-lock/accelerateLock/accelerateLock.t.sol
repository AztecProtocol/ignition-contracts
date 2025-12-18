// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {
    IGovernanceAcceleratedLock,
    GovernanceAcceleratedLock
} from "src/uniswap-periphery/GovernanceAcceleratedLock.sol";
import {Ownable} from "@oz/access/Ownable.sol";

import {Test} from "forge-std/Test.sol";

contract AcclerateLock is Test {
    GovernanceAcceleratedLock public governanceAcceleratedLock;
    address public governance = makeAddr("governance");

    function setUp() external {
        governanceAcceleratedLock = new GovernanceAcceleratedLock(governance, block.timestamp + 1000);
    }

    function test_WhenCallerNEQOwner(address _caller) external {
        // it reverts with OnlyOwner

        vm.assume(_caller != governance);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        governanceAcceleratedLock.accelerateLock();
    }

    function test_WhenCallerEQOwner() external {
        // it emits LockAccelerated
        // it sets lockAccelerated

        vm.expectEmit(true, true, true, true, address(governanceAcceleratedLock));
        emit IGovernanceAcceleratedLock.LockAccelerated();
        vm.prank(governance);
        governanceAcceleratedLock.accelerateLock();

        assertTrue(governanceAcceleratedLock.lockAccelerated());
    }
}
