// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {SoulboundBase} from "../SoulboundBase.t.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract FixedSaleStartSaleTest is SoulboundBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfSetScreeningProviderIsNotOwner(address _caller, address _screeningProvider) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        soulboundToken.setAddressScreeningProvider(_screeningProvider);
    }

    function test_WhenCallerOfSetScreeningProviderIsOwner(address _screeningProvider) external {
        // it sets the screening provider
        // it emits a {ScreeningProviderSet} event

        vm.expectEmit(true, true, true, true, address(soulboundToken));
        emit IIgnitionParticipantSoulbound.AddressScreeningProviderSet(_screeningProvider);
        vm.prank(address(this));
        soulboundToken.setAddressScreeningProvider(_screeningProvider);

        assertEq(soulboundToken.addressScreeningProvider(), _screeningProvider);
    }
}
