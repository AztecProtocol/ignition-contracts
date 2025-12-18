// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Math} from "@oz/utils/math/Math.sol";
import {Ownable} from "@oz/access/Ownable.sol";

import {LATPTestBase} from "test/token-vaults/latp_base.sol";

import {LATP, ILATP, IATPCore, IRegistry, LockParams, Lock, LockLib, RevokableParams} from "test/token-vaults/Importer.sol";

contract SetRevokerOperatorTest is LATPTestBase {
    ILATP internal atp;

    address internal oldRevokerOperator;

    function setUp() public override(LATPTestBase) {
        super.setUp();

        oldRevokerOperator = registry.getRevokerOperator();
    }

    function test_WhenCallerNEQOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        registry.setRevokerOperator(address(1));

        assertEq(registry.getRevokerOperator(), oldRevokerOperator, "revoker operator mismatch");
    }

    function test_WhenCallerIsOwner(address _newRevokerOperator) external {
        // it reverts
        vm.assume(_newRevokerOperator != oldRevokerOperator);
        registry.setRevokerOperator(_newRevokerOperator);

        assertEq(registry.getRevokerOperator(), _newRevokerOperator, "revoker operator mismatch");
    }
}
