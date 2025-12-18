// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";

import {LATPTestBase} from "test/token-vaults/latp_base.sol";
import {Math} from "@oz/utils/math/Math.sol";

import {
    LATP,
    ILATP,
    ILATPCore,
    IATPCore,
    ATPFactory,
    Aztec,
    LockParams,
    Lock,
    LockLib,
    RevokableParams
} from "test/token-vaults/Importer.sol";

contract RevokeTest is LATPTestBase {
    ILATP internal atp;
    uint256 internal claimed = 0;
    address internal revoker;
    uint256 allocation = 1000e18;

    function setUp() public override {
        unlockCliffDuration = 0;
        unlockLockDuration = 1000;

        super.setUp();
        revoker = registry.getRevoker();
    }

    function test_GivenNonRevokableLock() external {
        // it reverts {NotRevokable()}

        atp = atpFactory.createLATP(
            address(this), allocation, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
        );

        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotRevokable.selector));
        atp.revoke();
    }

    modifier givenRevokableLock() {
        atp = atpFactory.createLATP(
            address(this),
            allocation,
            RevokableParams({
                revokeBeneficiary: revokeBeneficiary,
                lockParams: LockParams({startTime: block.timestamp, cliffDuration: 0, lockDuration: 1000})
            })
        );

        _;
    }

    function test_WhenCallerNEQRevoker(address _caller) external givenRevokableLock {
        // it reverts {NotRevoker()}
        vm.assume(_caller != revoker);
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotRevoker.selector, _caller, revoker));
        atp.revoke();
    }

    modifier whenCallerEQRevoker() {
        _;
    }

    function test_GivenAlreadyRevoked() external givenRevokableLock whenCallerEQRevoker {
        // it reverts {AlreadyRevoked()}

        vm.prank(revoker);
        atp.revoke();

        vm.prank(revoker);
        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotRevokable.selector));
        atp.revoke();
    }

    modifier givenNotRevoked() {
        _;
    }

    function test_GivenLockHasEnded() external givenRevokableLock whenCallerEQRevoker givenNotRevoked {
        // it reverts {LockHasEnded()}

        uint256 endTime = atp.getAccumulationLock().endTime;

        vm.warp(endTime);

        vm.prank(revoker);
        vm.expectRevert(abi.encodeWithSelector(IATPCore.LockHasEnded.selector));
        atp.revoke();
    }

    function test_GivenLockHasNotEnded(uint256 _time) external givenRevokableLock whenCallerEQRevoker givenNotRevoked {
        // it sets isRevoked to true

        uint256 endTime = atp.getAccumulationLock().endTime;
        uint256 time = bound(_time, block.timestamp, endTime - 1);

        uint256 accumulated = help_computeAccumulated(atp, time);
        uint256 debt = allocation - accumulated;

        vm.warp(time);

        assertEq(atp.getRevokableAmount(), debt);
        assertEq(atp.getIsRevokable(), true);

        vm.prank(revoker);
        vm.expectEmit(true, true, true, true, address(atp));
        emit IATPCore.Revoked(debt);
        uint256 revoked = atp.revoke();

        assertEq(revoked, debt);
        assertEq(atp.getIsRevokable(), false);
        assertEq(token.balanceOf(revokeBeneficiary), debt);
        assertEq(token.balanceOf(address(atp)), accumulated);
    }
}
