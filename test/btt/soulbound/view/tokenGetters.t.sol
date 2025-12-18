// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {SoulboundBase} from "../SoulboundBase.t.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";

contract TokenGetters is SoulboundBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenTheAddressDoesNotHaveTheToken(address _addr) external view {
        // It returns false
        vm.assume(_addr != address(0));
        assumeAddress(_addr);

        assertFalse(soulboundToken.hasGenesisSequencerToken(_addr));
        assertFalse(soulboundToken.hasContributorToken(_addr));
        assertFalse(soulboundToken.hasGenesisSequencerTokenOrContributorToken(_addr));
        assertFalse(soulboundToken.hasGeneralToken(_addr));
        assertFalse(soulboundToken.hasAnyToken(_addr));
    }

    function test_WhenTheAddressHasGenesisSequencerToken(address _addr) external {
        // It returns true
        vm.assume(_addr != address(0));
        assumeAddress(_addr);

        soulboundToken.adminMint(_addr, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, gridTileId);

        assertTrue(soulboundToken.hasGenesisSequencerToken(_addr));
        assertTrue(soulboundToken.hasGenesisSequencerTokenOrContributorToken(_addr));
        assertTrue(soulboundToken.hasAnyToken(_addr));

        assertFalse(soulboundToken.hasContributorToken(_addr));
        assertFalse(soulboundToken.hasGeneralToken(_addr));
    }

    function test_WhenTheAddressHasContributorToken(address _addr) external {
        // It returns true
        vm.assume(_addr != address(0));
        assumeAddress(_addr);

        soulboundToken.adminMint(_addr, IIgnitionParticipantSoulbound.TokenId.CONTRIBUTOR, gridTileId);

        assertTrue(soulboundToken.hasContributorToken(_addr));
        assertTrue(soulboundToken.hasGenesisSequencerTokenOrContributorToken(_addr));
        assertTrue(soulboundToken.hasAnyToken(_addr));

        assertFalse(soulboundToken.hasGenesisSequencerToken(_addr));
        assertFalse(soulboundToken.hasGeneralToken(_addr));
    }

    function test_WhenTheAddressHasGeneralToken(address _addr) external {
        // It returns true
        vm.assume(_addr != address(0));
        assumeAddress(_addr);

        soulboundToken.adminMint(_addr, IIgnitionParticipantSoulbound.TokenId.GENERAL, gridTileId);

        assertTrue(soulboundToken.hasGeneralToken(_addr));
        assertTrue(soulboundToken.hasAnyToken(_addr));

        assertFalse(soulboundToken.hasGenesisSequencerTokenOrContributorToken(_addr));
        assertFalse(soulboundToken.hasGenesisSequencerToken(_addr));
        assertFalse(soulboundToken.hasContributorToken(_addr));
    }
}
