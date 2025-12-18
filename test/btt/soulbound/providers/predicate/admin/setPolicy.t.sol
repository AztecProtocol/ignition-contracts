// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IPredicateProvider} from "src/soulbound/providers/PredicateProvider.sol";
import {PredicateBase} from "../PredicateBase.sol";
import {Ownable} from "@oz/access/Ownable.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract PredicateSetPolicyTest is PredicateBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfSetPolicyIsNotOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        predicateProvider.setPolicy("test");
    }

    function test_WhenCallerOfSetPolicyIsOwner(address _address, string memory _policyID) external {
        // it sets the consumer
        // it emits a {PolicySet} event
        vm.assume(_address != address(this));

        vm.expectEmit(true, true, true, true, address(predicateProvider));
        emit IPredicateProvider.PolicySet(_policyID);
        predicateProvider.setPolicy(_policyID);

        assertEq(predicateProvider.getPolicy(), _policyID);
    }
}
