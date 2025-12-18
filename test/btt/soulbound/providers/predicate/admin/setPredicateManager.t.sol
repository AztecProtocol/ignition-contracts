// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IPredicateProvider} from "src/soulbound/providers/PredicateProvider.sol";
import {PredicateBase} from "../PredicateBase.sol";
import {Ownable} from "@oz/access/Ownable.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract PredicateSetPredicateManagerTest is PredicateBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfSetPredicateManagerIsNotOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        predicateProvider.setPredicateManager(address(1));
    }

    function test_WhenCallerOfSetPredicateManagerIsOwner(address _address, address _predicateManager) external {
        // it sets the predicate manager
        // it emits a {PredicateManagerSet} event
        vm.assume(_address != address(this));

        vm.expectEmit(true, true, true, true, address(predicateProvider));
        emit IPredicateProvider.PredicateManagerSet(_predicateManager);
        predicateProvider.setPredicateManager(_predicateManager);

        assertEq(address(predicateProvider.getPredicateManager()), _predicateManager);
    }
}
