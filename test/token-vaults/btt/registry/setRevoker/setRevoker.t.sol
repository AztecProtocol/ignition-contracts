// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Math} from "@oz/utils/math/Math.sol";
import {Ownable} from "@oz/access/Ownable.sol";

import {LATPTestBase} from "test/token-vaults/latp_base.sol";

import {LATP, ILATP, IATPCore, IRegistry, LockParams, Lock, LockLib, RevokableParams} from "test/token-vaults/Importer.sol";

contract SetRevokerTest is LATPTestBase {
    ILATP internal atp;

    address internal oldRevoker;

    function setUp() public override(LATPTestBase) {
        super.setUp();

        uint256 allocation = 100e18;

        atp = atpFactory.createLATP(
            address(this),
            allocation,
            RevokableParams({
                revokeBeneficiary: revokeBeneficiary,
                lockParams: LockParams({startTime: block.timestamp, cliffDuration: 250, lockDuration: 1000})
            })
        );

        oldRevoker = atp.getRevoker();
        assertEq(registry.getRevoker(), oldRevoker, "revoker mismatch");
    }

    function test_WhenCallerNEQOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        registry.setRevoker(address(0));

        assertEq(registry.getRevoker(), oldRevoker, "revoker mismatch");
    }

    function test_NewRevokerCanRevoke(address _newRevoker) external {
        // it reverts
        vm.assume(_newRevoker != oldRevoker);

        uint256 allocation = atp.getAllocation();

        // try using the `_newRevoker` to revoke the LATP.
        // Why is this not failing?
        vm.prank(address(_newRevoker));
        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotRevoker.selector, _newRevoker, oldRevoker));
        atp.revoke();

        // Now we update the revoker and try again
        vm.expectEmit(true, true, true, true);
        emit IRegistry.UpdatedRevoker(_newRevoker);
        registry.setRevoker(_newRevoker);

        assertEq(registry.getRevoker(), _newRevoker, "revoker mismatch");

        vm.prank(address(_newRevoker));
        uint256 amount = atp.revoke();
        assertGt(amount, 0, "revoked amount");

        assertEq(token.balanceOf(address(atp)), allocation - amount, "balance mismatch");
        assertEq(token.balanceOf(revokeBeneficiary), amount, "revoker balance mismatch");
    }
}
