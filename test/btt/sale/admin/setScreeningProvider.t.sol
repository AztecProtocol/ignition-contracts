// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IGenesisSequencerSale} from "../../../../src/sale/GenesisSequencerSale.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {GenesisSequencerSaleBase} from "../GenesisSequencerSaleBase.t.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract FixedSaleSetScreeningProviderTest is GenesisSequencerSaleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfSetScreeningProviderIsNotOwner(address _caller) external {
        // it reverts
        address _screeningProvider = address(mockFalseWhitelistProvider);
        vm.assume(_caller != FOUNDATION_ADDRESS);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        genesisSequencerSale.setAddressScreeningProvider(_screeningProvider);
    }

    function test_WhenCallerOfSetScreeningProviderIsZeroAddress() external {
        // it reverts

        vm.expectRevert(abi.encodeWithSelector(IGenesisSequencerSale.GenesisSequencerSale__ZeroAddress.selector));
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.setAddressScreeningProvider(address(0));
    }

    function test_WhenCallerOfSetScreeningProviderIsOwner(address _screeningProvider) external {
        // it sets a screening provider
        // it emits a {ScreeningProviderSet} event
        vm.assume(_screeningProvider != address(0));

        vm.expectEmit(true, true, true, true, address(genesisSequencerSale));
        emit IGenesisSequencerSale.ScreeningProviderSet(_screeningProvider);
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.setAddressScreeningProvider(_screeningProvider);

        assertEq(genesisSequencerSale.addressScreeningProvider(), _screeningProvider);
    }
}
