// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {SoulboundBase} from "../SoulboundBase.t.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract SetGenesisSequencerSale is SoulboundBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfSetGenesisSequencerSaleIsNotOwner(address _caller, address _tokenSaleAddress) external {
        // it reverts with {OwnableUnauthorizedAccount()}
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        soulboundToken.setTokenSaleAddress(_tokenSaleAddress);
    }

    function test_WhenCallerOfSetGenesisSequencerSaleIsOwner(address _tokenSaleAddress) external {
        // it sets the genesis sequencer sale
        // it emits a {TokenSaleAddressSet} event

        vm.expectEmit(true, true, true, true, address(soulboundToken));
        emit IIgnitionParticipantSoulbound.TokenSaleAddressSet(_tokenSaleAddress);
        vm.prank(address(this));
        soulboundToken.setTokenSaleAddress(_tokenSaleAddress);

        assertEq(soulboundToken.tokenSaleAddress(), _tokenSaleAddress);
    }
}
