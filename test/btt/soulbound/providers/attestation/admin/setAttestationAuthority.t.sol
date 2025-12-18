// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IAttestationProvider} from "src/soulbound/providers/AttestationProvider.sol";
import {AttestationBase} from "../AttestationBase.sol";
import {Ownable} from "@oz/access/Ownable.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract AttestationSetAttestationAuthorityTest is AttestationBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfSetAttestationAuthorityIsNotOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        attestationProvider.setAttestationAuthority(address(1));
    }

    function test_WhenCallerOfSetAttestationAuthorityIsOwner(address _attestationAuthority) external {
        // it sets the attestation authority
        // it emits a {AttestationAuthoritySet} event

        vm.expectEmit(true, true, true, true, address(attestationProvider));
        emit IAttestationProvider.AttestationAuthoritySet(_attestationAuthority);
        attestationProvider.setAttestationAuthority(_attestationAuthority);
        assertTrue(address(attestationProvider.attestationAuthority()) == _attestationAuthority);
    }
}
