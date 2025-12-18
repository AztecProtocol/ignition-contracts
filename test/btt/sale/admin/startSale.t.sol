// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IGenesisSequencerSale} from "../../../../src/sale/GenesisSequencerSale.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {GenesisSequencerSaleBase} from "../GenesisSequencerSaleBase.t.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract FixedSaleStartSaleTest is GenesisSequencerSaleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfStartSaleIsNotOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != FOUNDATION_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        genesisSequencerSale.startSale();
    }

    function test_WhenCallerOfStartSaleIsOwner() external {
        // it starts the sale
        // it emits a {SaleStarted} event

        vm.expectEmit(true, true, true, true, address(genesisSequencerSale));
        emit IGenesisSequencerSale.SaleStarted(SALE_START_TIME, SALE_END_TIME);
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.startSale();

        assertTrue(genesisSequencerSale.saleEnabled());
        assertEq(genesisSequencerSale.saleStartTime(), SALE_START_TIME);
        assertEq(genesisSequencerSale.saleEndTime(), SALE_END_TIME);
    }
}
