// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IZKPassportProviderLegacy} from "src/soulbound/providers/ZKPassportProviderLegacy.sol";
import {ZKPassportBase} from "../ZKPassportBase.sol";
import {Ownable} from "@oz/access/Ownable.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract ZKPassportSetZKPassportVerifierTest is ZKPassportBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfSetZKPassportVerifierIsNotOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        zkPassportProvider.setZKPassportVerifier(address(1));
    }

    function test_WhenCallerOfSetZKPassportVerifierIsOwner(address _address) external {
        // it sets the zk passport verifier
        // it emits a {ZKPassportVerifierSet} event
        vm.assume(_address != address(this));

        vm.expectEmit(true, true, true, true, address(zkPassportProvider));
        emit IZKPassportProviderLegacy.ZKPassportVerifierSet(_address);
        zkPassportProvider.setZKPassportVerifier(_address);
        assertTrue(address(zkPassportProvider.zkPassportVerifier()) == _address);
    }
}
