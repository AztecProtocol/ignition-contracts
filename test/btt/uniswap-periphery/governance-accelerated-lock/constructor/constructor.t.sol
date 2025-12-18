// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {
    IGovernanceAcceleratedLock, GovernanceAcceleratedLock
} from "src/uniswap-periphery/GovernanceAcceleratedLock.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {Test} from "forge-std/Test.sol";

contract ConstructorTest is Test {
    function test_WhenGovernanceAddressEQZero(uint64 _startTime, uint64 _timestamp) external {
        // it reverts with GovernanceAddressCannotBeZero

        vm.assume(_startTime > 2);
        _timestamp = uint64(bound(uint256(_timestamp), 0, uint256(_startTime - 1)));

        vm.warp(_timestamp);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new GovernanceAcceleratedLock(address(0), uint256(_startTime));
    }

    function test_WhenGovernanceAddressNEQZero(uint64 _startTime, uint64 _timestamp, address _governance) external {
        // it sets start time
        // it sets governance address to owner
        // it sets lockAccelerated to false

        vm.assume(_governance != address(0));
        vm.assume(_startTime > 2);
        _timestamp = uint64(bound(uint256(_timestamp), 0, uint256(_startTime - 1)));

        vm.warp(_timestamp);

        GovernanceAcceleratedLock govLock = new GovernanceAcceleratedLock(_governance, uint256(_startTime));

        assertEq(govLock.START_TIME(), uint256(_startTime));
        assertEq(govLock.EXTENDED_LOCK_TIME(), 365 days);
        assertEq(govLock.SHORTER_LOCK_TIME(), 90 days);
        assertEq(govLock.owner(), _governance);
        assertEq(govLock.lockAccelerated(), false);
    }
}
