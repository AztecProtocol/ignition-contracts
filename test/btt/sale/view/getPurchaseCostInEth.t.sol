// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {GenesisSequencerSaleBase} from "../GenesisSequencerSaleBase.t.sol";
import {IGenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";

contract GetPurchaseCostInEth is GenesisSequencerSaleBase {
    uint256 public PURCHASES_PER_ADDRESS;

    function setUp() public override {
        super.setUp();

        PURCHASES_PER_ADDRESS = genesisSequencerSale.PURCHASES_PER_ADDRESS();
    }

    function test_GetPurchaseCostInEth() external view {
        // It returns the purchase cost in ETH
        assertEq(genesisSequencerSale.getPurchaseCostInEth(), pricePerLot * PURCHASES_PER_ADDRESS);
    }

    function test_WhenUpdatingThePricePerLot() external {
        // It updates the price per lot
        uint256 newPricePerLot = 10 ether;
        vm.expectEmit(true, true, true, true, address(genesisSequencerSale));
        emit IGenesisSequencerSale.PriceUpdated(newPricePerLot);
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.setPricePerLotInEth(newPricePerLot);

        assertEq(genesisSequencerSale.getPurchaseCostInEth(), newPricePerLot * PURCHASES_PER_ADDRESS);
    }
}
