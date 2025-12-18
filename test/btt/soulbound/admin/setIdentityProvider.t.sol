// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {SoulboundBase} from "../SoulboundBase.t.sol";
import {Ownable} from "@oz/access/Ownable.sol";

contract SetEligibilityProvider is SoulboundBase {
    function setUp() public override {
        super.setUp();
    }

    function test_shouldSetEligibilityProviderWhenCallerIsOwner(address _provider, bool _active) public {
        vm.expectEmit(true, true, true, true);
        emit IIgnitionParticipantSoulbound.IdentityProviderSet(_provider, _active);
        soulboundToken.setIdentityProvider(_provider, _active);

        assertEq(soulboundToken.identityProviders(_provider), _active);
    }

    function test_shouldRevertWhenCallerIsNotOwner(address _provider, bool _active, address _caller) public {
        vm.assume(_caller != address(this));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        soulboundToken.setIdentityProvider(_provider, _active);
    }
}
