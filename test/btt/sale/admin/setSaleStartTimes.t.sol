// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IGenesisSequencerSale} from "../../../../src/sale/GenesisSequencerSale.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {GenesisSequencerSaleBase} from "../GenesisSequencerSaleBase.t.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract FixedSaleSetSaleTimesTest is GenesisSequencerSaleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfSetSaleTimesIsNotOwner(address _caller, uint96 _saleStartTime, uint96 _saleEndTime)
        external
    {
        // it reverts
        vm.assume(_caller != FOUNDATION_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        genesisSequencerSale.setSaleTimes(_saleStartTime, _saleEndTime);
    }

    function test_WhenSaleStartTimeIsGreaterThanSaleEndTime() external {
        // it reverts
        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__InvalidTimeRange.selector);
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.setSaleTimes(uint96(block.timestamp + 1), uint96(block.timestamp));
    }

    function test_WhenSaleStartTimeIsLessThanBlockTimestamp() external {
        // it reverts
        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__InvalidTimeRange.selector);
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.setSaleTimes(uint96(block.timestamp - 1), uint96(block.timestamp));
    }

    function test_WhenCallerOfSetSaleTimesIsOwner(uint96 _saleStartTime, uint96 _saleEndTime) external {
        // it sets the sale start and end times
        // it emits a {SaleTimesUpdated} event
        vm.assume(_saleStartTime > 0);
        vm.assume(_saleStartTime < _saleEndTime);
        vm.assume(_saleStartTime >= block.timestamp);

        vm.expectEmit(true, true, true, true, address(genesisSequencerSale));
        emit IGenesisSequencerSale.SaleTimesUpdated(_saleStartTime, _saleEndTime);
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.setSaleTimes(_saleStartTime, _saleEndTime);

        assertEq(genesisSequencerSale.saleStartTime(), _saleStartTime);
        assertEq(genesisSequencerSale.saleEndTime(), _saleEndTime);
    }
}
