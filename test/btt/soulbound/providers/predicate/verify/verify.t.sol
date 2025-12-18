// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IPredicateProvider} from "src/soulbound/providers/PredicateProvider.sol";
import {IWhitelistProvider} from "src/soulbound/providers/IWhitelistProvider.sol";
import {PredicateBase} from "../PredicateBase.sol";
import {PredicateMessage} from "@predicate/interfaces/IPredicateClient.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract PredicateVerifyTest is PredicateBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfVerifyIsNotConsumer(address _caller, address _user) external {
        // it reverts with {InvalidConsumer}

        PredicateMessage memory attestation = makePredicateAttestation();

        vm.assume(_caller != consumer);

        vm.expectRevert(abi.encodeWithSelector(IWhitelistProvider.WhitelistProvider__InvalidConsumer.selector));
        vm.prank(_caller);
        predicateProvider.verify(_user, abi.encode(attestation));
    }

    function test_WhenCallerOfVerifyIsConsumer(address _user) external {
        // it verifies the message
        // it returns true
        makePredicateSucceed();

        PredicateMessage memory attestation = makePredicateAttestation();
        vm.prank(consumer);
        bool result = predicateProvider.verify(_user, abi.encode(attestation));
        assertTrue(result);
    }

    function test_WhenPredicateFails(address _user) external {
        // it reverts with {AuthorizationFailed}
        makePredicateFail();

        PredicateMessage memory attestation = makePredicateAttestation();
        vm.expectRevert(abi.encodeWithSelector(IPredicateProvider.PredicateProvider__AuthorizationFailed.selector));
        vm.prank(consumer);
        predicateProvider.verify(_user, abi.encode(attestation));
    }
}
