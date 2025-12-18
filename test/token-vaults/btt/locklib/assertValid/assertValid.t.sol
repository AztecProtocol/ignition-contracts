// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {LockParams, LockLib} from "test/token-vaults/Importer.sol";

contract LibWrapper {
    function assertValid(LockParams memory _params) external pure {
        LockLib.assertValid(_params);
    }

    function test() external virtual {
        // @dev To avoid this being included in the coverage results
        // https://github.com/foundry-rs/foundry/issues/2988#issuecomment-1437784542
    }
}

contract AssertValidTest is Test {
    LibWrapper internal libWrapper;

    function setUp() external {
        libWrapper = new LibWrapper();
    }

    function test_WhenLockDurationEQZero() external {
        // it reverts

        vm.expectRevert(LockLib.LockDurationMustBeGTZero.selector);
        libWrapper.assertValid(LockParams({startTime: 0, cliffDuration: 0, lockDuration: 0}));

        vm.expectRevert(LockLib.LockDurationMustBeGTZero.selector);
        libWrapper.assertValid(LockLib.empty());
    }

    modifier whenLockDurationGTZero() {
        _;
    }

    function test_WhenLockDurationLTCliffDuration(uint256 _cliffDuration, uint256 _duration)
        external
        whenLockDurationGTZero
    {
        // it reverts

        uint256 duration = bound(_duration, 1, type(uint256).max - 1);
        uint256 cliffDuration = bound(_cliffDuration, duration + 1, type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(LockLib.LockDurationMustBeGECliffDuration.selector, duration, cliffDuration)
        );
        libWrapper.assertValid(LockParams({startTime: 0, cliffDuration: cliffDuration, lockDuration: duration}));
    }

    function test_WhenLockDurationGECliffDuration(uint256 _cliffDuration, uint256 _duration)
        external
        view
        whenLockDurationGTZero
    {
        // it passes

        uint256 duration = bound(_duration, 1, type(uint256).max - 1);
        uint256 cliffDuration = bound(_cliffDuration, 0, duration);

        LockParams memory params = LockParams({startTime: 0, cliffDuration: cliffDuration, lockDuration: duration});

        libWrapper.assertValid(params);
    }
}
