// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {GenesisSequencerSaleBase} from "../GenesisSequencerSaleBase.t.sol";

contract IsSaleActive is GenesisSequencerSaleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenTheSaleIsNotEnabled() external {
        // It returns false
        isSaleActive(false);
        hasSaleStarted(false);

        assertFalse(genesisSequencerSale.isSaleActive());
    }

    function test_whenTheSaleHasNotStarted() external {
        // It returns false
        isSaleActive(true);
        hasSaleStarted(false);

        assertFalse(genesisSequencerSale.isSaleActive());
    }

    function test_WhenTheSaleHasStartedAndIsEnabled() external {
        // It returns true
        isSaleActive(true);
        hasSaleStarted(true);

        assertTrue(genesisSequencerSale.isSaleActive());
    }
}
