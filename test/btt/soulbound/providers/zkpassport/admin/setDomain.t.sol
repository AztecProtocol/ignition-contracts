// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IZKPassportProviderLegacy} from "src/soulbound/providers/ZKPassportProviderLegacy.sol";
import {ZKPassportBase} from "../ZKPassportBase.sol";
import {Ownable} from "@oz/access/Ownable.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract ZKPassportSetDomainTest is ZKPassportBase {
    function setUp() public override {
        super.setUp();
    }

    // TODO: fuzz string values
    function test_WhenCallerOfSetDomainIsNotOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        zkPassportProvider.setDomain("test");
    }

    function test_WhenCallerOfSetDomainIsOwner(address _address) external {
        // it sets the domain
        // it emits a {DomainSet} event
        vm.assume(_address != address(this));

        vm.expectEmit(true, true, true, true, address(zkPassportProvider));
        emit IZKPassportProviderLegacy.DomainSet("test");
        zkPassportProvider.setDomain("test");
        assertTrue(keccak256(bytes(zkPassportProvider.domain())) == keccak256(bytes("test")));
    }
}
