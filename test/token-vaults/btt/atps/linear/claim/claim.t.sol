// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@oz/interfaces/draft-IERC6093.sol";

import {LATPTestBase} from "test/token-vaults/latp_base.sol";

import {
    LATP,
    ILATP,
    IATPCore,
    ATPFactory,
    IRegistry,
    Registry,
    Aztec,
    LockParams,
    Lock,
    LockLib,
    RevokableParams
} from "test/token-vaults/Importer.sol";

contract ClaimTest is LATPTestBase {
    ILATP internal atp;
    Lock internal lock;
    uint256 internal claimed = 0;

    function setUp() public override(LATPTestBase) {
        unlockCliffDuration = 0;

        super.setUp();

        atp = atpFactory.createLATP(
            address(this), 1000e18, RevokableParams({lockParams: LockLib.empty(), revokeBeneficiary: address(0)})
        );
        lock = atp.getGlobalLock();
    }

    function test_WhenCallerIsNotBeneficiary(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotBeneficiary.selector, _caller, address(this)));
        vm.prank(_caller);
        atp.claim();
    }

    modifier whenCallerIsBeneficiary() {
        _;
    }

    function test_WhenClaimableIsZero() external whenCallerIsBeneficiary {
        // it reverts

        // Simplest way is that we "delete" the funds.
        deal(address(token), address(atp), 0);

        vm.expectRevert(abi.encodeWithSelector(IATPCore.NoClaimable.selector));
        atp.claim();
    }

    modifier whenClaimableIsGreaterThanZero() {
        _;
    }

    function test_WhenTokenTransferFails() external whenCallerIsBeneficiary whenClaimableIsGreaterThanZero {
        // it reverts and does not update claimed
        // In this case, we make it revert since we convince it that it have a larger than real balance.

        uint256 allocation = atp.getAllocation();

        // We end the lock
        vm.warp(lock.endTime);

        vm.mockCall(
            address(token), abi.encodeWithSelector(IERC20.balanceOf.selector, address(atp)), abi.encode(allocation * 2)
        );

        uint256 claimable = atp.getClaimable();
        assertGt(claimable, 0, "nothing to claim");

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(atp), allocation, allocation * 2
            )
        );
        atp.claim();
    }

    modifier whenTokenTransferSucceeds(uint256 _time) {
        uint256 timeLimit = (lock.endTime - lock.cliff) / 2;

        uint256 lower = lock.startTime == lock.cliff ? lock.cliff + 1 : lock.cliff;
        uint256 time = bound(_time, lower, timeLimit);
        vm.warp(time);

        uint256 claimable = atp.getClaimable();
        assertGt(claimable, 0, "claimable is zero");

        claimed += claimable;

        vm.expectEmit(true, true, true, true, address(atp));
        emit IATPCore.Claimed(claimable);
        atp.claim();

        _;
    }

    function test_WhenTokenTransferSucceeds(uint256 _time)
        external
        whenCallerIsBeneficiary
        whenClaimableIsGreaterThanZero
        whenTokenTransferSucceeds(_time)
    {
        // it updates claimed with claimable amount
        // it transfers tokens to beneficiary

        assertEq(claimed, atp.getClaimed());
        assertEq(token.balanceOf(address(this)), claimed);
        assertEq(token.balanceOf(address(atp)), atp.getAllocation() - claimed);
    }

    function test_WhenCheckingSubsequentClaims(uint256 _time1, uint256 _time2)
        external
        whenCallerIsBeneficiary
        whenClaimableIsGreaterThanZero
        whenTokenTransferSucceeds(_time1)
    {
        // it returns zero immediately after claim
        // it accumulates new claimable amount after time passes

        assertEq(atp.getClaimable(), 0, "claimable is not zero");

        uint256 time2 = bound(_time2, block.timestamp + 1, lock.endTime);
        uint256 accumulated = lock.allocation * (time2 - block.timestamp) / (lock.endTime - lock.startTime);

        vm.warp(time2);

        uint256 claimable = atp.getClaimable();
        assertGt(claimable, 0, "claimable is zero");
        assertEq(claimable, accumulated, "claimable is not accumulated");

        claimed += claimable;

        vm.expectEmit(true, true, true, true, address(atp));
        emit IATPCore.Claimed(claimable);
        assertEq(atp.claim(), claimable, "invalid claimable");

        assertEq(claimed, atp.getClaimed(), "invalid claimed");
        assertEq(token.balanceOf(address(this)), claimed, "invalid balance (this)");
        assertEq(token.balanceOf(address(atp)), atp.getAllocation() - claimed, "invalid balance (atp)");
    }
}
