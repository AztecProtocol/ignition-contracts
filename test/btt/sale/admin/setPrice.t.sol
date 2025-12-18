// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IGenesisSequencerSale} from "../../../../src/sale/GenesisSequencerSale.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {GenesisSequencerSaleBase} from "../GenesisSequencerSaleBase.t.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract FixedSaleSetPriceTest is GenesisSequencerSaleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfSetPriceIsNotOwner(address _caller, uint256 _pricePerLot) external {
        // it reverts
        vm.assume(_caller != FOUNDATION_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        genesisSequencerSale.setPricePerLotInEth(_pricePerLot);
    }

    function test_WhenPriceIsZero() external {
        // it reverts
        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__InvalidPrice.selector);
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.setPricePerLotInEth(0);
    }

    function test_WhenCallerOfSetPriceIsOwner(uint256 _pricePerLot) external {
        // it sets the price
        // it emits a {PriceUpdated} event
        vm.assume(_pricePerLot > 0);

        vm.expectEmit(true, true, true, true, address(genesisSequencerSale));
        emit IGenesisSequencerSale.PriceUpdated(_pricePerLot);
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.setPricePerLotInEth(_pricePerLot);
    }
}
