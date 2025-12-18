// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IZKPassportProviderLegacy} from "src/soulbound/providers/ZKPassportProviderLegacy.sol";
import {ZKPassportBase} from "../ZKPassportBase.sol";
import {Ownable} from "@oz/access/Ownable.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract ZKPassportSetScopeTest is ZKPassportBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfSetScopeIsNotOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        zkPassportProvider.setScope("test");
    }

    function test_WhenCallerOfSetScopeIsOwner(address _address) external {
        // it sets the subscope
        // it emits a {SubscopeSet} event
        vm.assume(_address != address(this));

        vm.expectEmit(true, true, true, true, address(zkPassportProvider));
        emit IZKPassportProviderLegacy.ScopeSet("test");
        zkPassportProvider.setScope("test");
        assertTrue(keccak256(bytes(zkPassportProvider.scope())) == keccak256(bytes("test")));
    }
}
