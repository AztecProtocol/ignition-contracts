// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    IGovernanceAcceleratedLock,
    GovernanceAcceleratedLock
} from "src/uniswap-periphery/GovernanceAcceleratedLock.sol";
import {Ownable} from "@oz/access/Ownable.sol";

contract MockContract {
    function mockFunction() external pure returns (bool) {
        return true;
    }
}

contract RelayTest is Test {
    GovernanceAcceleratedLock public governanceAcceleratedLock;
    MockContract public mockContract;
    address public governance = makeAddr("governance");

    function setUp() external {
        governanceAcceleratedLock = new GovernanceAcceleratedLock(governance, block.timestamp + 1);
        mockContract = new MockContract();
    }

    modifier givenLockIsAccelerated() {
        vm.prank(governance);
        governanceAcceleratedLock.accelerateLock();
        _;
    }

    modifier givenCallerIsOwner() {
        _;
    }

    function getTarget() internal returns (address) {
        address target = makeAddr("target");
        vm.etch(target, address(mockContract).code);
        return target;
    }

    function test_whenCallerNEQOwner(address _caller) external {
        vm.assume(_caller != governance);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(_caller)));
        vm.prank(_caller);
        governanceAcceleratedLock.relay(address(1), bytes(""));
    }

    function test_When90DaysHasNotPassed(uint64 _now) external givenLockIsAccelerated givenCallerIsOwner {
        // it should revert with LockTimeNotMet
        uint256 startTime = governanceAcceleratedLock.START_TIME();
        uint256 shorterLockTime = governanceAcceleratedLock.SHORTER_LOCK_TIME();
        uint256 _now = uint256(bound(uint256(_now), 0, uint256(startTime + shorterLockTime - 1)));

        vm.warp(_now);

        address target = getTarget();
        vm.expectRevert(IGovernanceAcceleratedLock.GovernanceAcceleratedLock__LockTimeNotMet.selector);
        vm.prank(governance);
        governanceAcceleratedLock.relay(target, bytes(""));
    }

    function test_When90DaysHasPassed(uint64 _now) external givenLockIsAccelerated givenCallerIsOwner {
        // it should not revert
        uint256 startTime = governanceAcceleratedLock.START_TIME();
        uint256 shorterLockTime = governanceAcceleratedLock.SHORTER_LOCK_TIME();
        uint256 _now = uint256(bound(uint256(_now), uint256(startTime + shorterLockTime), type(uint64).max));

        vm.warp(_now);

        address target = getTarget();
        vm.prank(governance);
        governanceAcceleratedLock.relay(target, abi.encodeWithSelector(MockContract.mockFunction.selector));
    }

    modifier givenLockIsNotAccelerated() {
        _;
    }

    function test_When365DaysHasNotPassed(uint64 _now) external givenLockIsNotAccelerated givenCallerIsOwner {
        // it should revert with LockTimeNotMet
        uint256 startTime = governanceAcceleratedLock.START_TIME();
        uint256 extendedLockTime = governanceAcceleratedLock.EXTENDED_LOCK_TIME();
        uint256 _now = uint256(bound(uint256(_now), 0, uint256(startTime + extendedLockTime - 1)));

        vm.warp(_now);

        address target = getTarget();
        vm.expectRevert(IGovernanceAcceleratedLock.GovernanceAcceleratedLock__LockTimeNotMet.selector);
        vm.prank(governance);
        governanceAcceleratedLock.relay(target, bytes(""));
    }

    function test_When365DaysHasPassed(uint64 _now) external givenLockIsNotAccelerated givenCallerIsOwner {
        // it should not revert
        uint256 startTime = governanceAcceleratedLock.START_TIME();
        uint256 extendedLockTime = governanceAcceleratedLock.EXTENDED_LOCK_TIME();
        uint256 _now = uint256(bound(uint256(_now), uint256(startTime + extendedLockTime), type(uint64).max));

        vm.warp(_now);

        address target = getTarget();
        vm.prank(governance);
        governanceAcceleratedLock.relay(target, abi.encodeWithSelector(MockContract.mockFunction.selector));
    }
}
