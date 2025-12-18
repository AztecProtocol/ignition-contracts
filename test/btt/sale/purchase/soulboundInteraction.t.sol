// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {GenesisSequencerSaleBase} from "../GenesisSequencerSaleBase.t.sol";
import {IGenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";

contract SoulboundInteraction is GenesisSequencerSaleBase {
    function setUp() public override {
        super.setUp();
        isSaleActive(true);
        hasSaleStarted(true);
    }

    function test_WhenTheUserDoesNotHaveASoulboundToken(address _user, address _beneficiary) external {
        // It reverts with {NoSoulboundToken()}
        assumeAddress(_user);

        uint256 amount = pricePerLot * genesisSequencerSale.PURCHASES_PER_ADDRESS();
        vm.deal(_user, amount);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__NoSoulboundToken.selector);
        vm.prank(_user);
        genesisSequencerSale.purchase{value: amount}(_beneficiary, "");
    }

    function test_WhenTheCallerIsNotTheTokenSaleContract(address _user) external {
        assumeAddress(_user);
        vm.assume(_user != address(genesisSequencerSale));
        // It reverts with {IgnitionParticipantSoulbound__CallerIsNotTokenSale()}
        vm.prank(_user);
        vm.expectRevert(IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__CallerIsNotTokenSale.selector);
        soulboundToken.mintFromSale(
            _user,
            _user,
            new bytes32[](0),
            address(0),
            "",
            "",
            /*gridTileId*/
            1
        );
    }
}
