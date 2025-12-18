// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IGenesisSequencerSale} from "../../../../src/sale/GenesisSequencerSale.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {GenesisSequencerSaleBase} from "../GenesisSequencerSaleBase.t.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract FixedSaleEndSaleTest is GenesisSequencerSaleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfStopSaleIsNotOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != FOUNDATION_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        genesisSequencerSale.stopSale();
    }

    function test_WhenCallerOfEndSaleIsOwner() external {
        // it ends the sale
        // it emits a {SaleEnded} event

        vm.expectEmit(true, true, true, true, address(genesisSequencerSale));
        emit IGenesisSequencerSale.SaleStopped();
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.stopSale();
    }
}
