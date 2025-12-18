// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IWhitelistProvider} from "src/soulbound/providers/IWhitelistProvider.sol";
import {AttestationBase} from "../AttestationBase.sol";
import {Ownable} from "@oz/access/Ownable.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract AttestationSetConsumerTest is AttestationBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfSetConsumerIsNotOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        attestationProvider.setConsumer(address(1));
    }

    function test_WhenCallerOfSetConsumerIsOwner(address _address) external {
        // it sets the consumer
        // it emits a {ConsumerSet} event
        vm.assume(_address != address(this));

        vm.expectEmit(true, true, true, true, address(attestationProvider));
        emit IWhitelistProvider.ConsumerSet(_address);
        attestationProvider.setConsumer(_address);
        assertTrue(address(attestationProvider.consumer()) == _address);
    }
}
