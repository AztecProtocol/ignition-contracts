// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Ownable} from "@oz/access/Ownable.sol";

import {LATPTestBase} from "test/token-vaults/latp_base.sol";

import {LATP, ILATP, ILATPCore, IRegistry, LockParams, Lock, LockLib, RevokableParams} from "test/token-vaults/Importer.sol";

contract SetUnlockStartTimeTest is LATPTestBase {
    using LockLib for Lock;

    ILATP internal atp;

    function setUp() public override(LATPTestBase) {
        unlockStartTime = 1798761600 - 1;

        super.setUp();

        uint256 allocation = 100e18;

        atp = atpFactory.createLATP(
            address(this), allocation, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
        );
    }

    function test_WhenCallerNEQOwner(address _caller) external {
        // it reverts

        vm.assume(_caller != address(this));
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        registry.setUnlockStartTime(0);
    }

    modifier whenCallerEQOwner() {
        _;
    }

    function test_WhenNewUnlockStartTimeGECurrentUnlockStartTime(uint256 _newUnlockStartTime)
        external
        whenCallerEQOwner
    {
        // it reverts
        uint256 currentUnlockStartTime = registry.getUnlockStartTime();
        uint256 newUnlockStartTime = bound(_newUnlockStartTime, currentUnlockStartTime + 1, type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRegistry.InvalidUnlockStartTime.selector, newUnlockStartTime, currentUnlockStartTime
            )
        );
        registry.setUnlockStartTime(newUnlockStartTime);
    }

    function test_WhenNewUnlockStartTimeLTCurrentUnlockStartTime(uint256 _newUnlockStartTime, uint256 _time)
        external
        whenCallerEQOwner
    {
        // it updates the unlockStartTime

        // We will check that the claimable amounts are updated accordingly, as they are bounded by the
        // unlocks.

        uint256 currentUnlockStartTime = registry.getUnlockStartTime();
        uint256 newUnlockStartTime = bound(_newUnlockStartTime, 0, currentUnlockStartTime / 2);
        uint256 time = bound(_time, newUnlockStartTime, currentUnlockStartTime);

        uint256 allocation = atp.getAllocation();
        Lock memory lock = atp.getGlobalLock();
        Lock memory newLock = LockLib.createLock(
            LockParams({
                startTime: newUnlockStartTime,
                cliffDuration: lock.cliff - lock.startTime,
                lockDuration: lock.endTime - lock.startTime
            }),
            allocation
        );

        uint256 unlocked = lock.unlockedAt(time);
        uint256 newUnlocked = newLock.unlockedAt(time);

        vm.warp(time);
        assertEq(atp.getClaimable(), unlocked, "claimable mismatch");

        vm.expectEmit(true, true, true, true);
        emit IRegistry.UpdatedUnlockStartTime(newUnlockStartTime);
        registry.setUnlockStartTime(newUnlockStartTime);

        assertEq(registry.getUnlockStartTime(), newUnlockStartTime, "unlockStartTime mismatch");

        assertEq(atp.getClaimable(), newUnlocked, "claimable mismatch");
    }
}
