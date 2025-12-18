// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {MockTrueWhitelistProvider} from "test/mocks/MockWhitelistProvider.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {SoulboundBase} from "./SoulboundBase.t.sol";
import {TestMerkleTreeGetters} from "test/merkle-tree/merkle_tree_getters.sol";

contract TransferSoulboundToken is SoulboundBase, TestMerkleTreeGetters {
    function setUp() public override {
        super.setUp();
        initTrees();
    }

    /// forge-config: default.fuzz.runs = 10
    function test_RevertWhen_SetApprovalForAllIsCalled(address _user) external {
        assumeAddress(_user);
        vm.prank(_user);
        vm.expectRevert(IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__TokenIsSoulbound.selector);
        soulboundToken.setApprovalForAll(address(1), true);
    }

    /// forge-config: default.fuzz.runs = 10
    function test_shouldNotTransferSoulboundToken(uint8 _userIndex, address _beneficiary, address _to, uint8 _tokenId)
        public
    {
        assumeAddress(_to);
        assumeAddress(_beneficiary);

        _tokenId = boundTokenId(_tokenId);
        _userIndex = boundTreeIndex(_userIndex);

        (address _user, bytes32[] memory merkleProof) =
            getAddressAndProof(_userIndex, TestMerkleTreeGetters.MerkleTreeType(_tokenId));

        setMockTrueScreeningProvider();

        vm.expectEmit(true, true, true, true, address(soulboundToken));
        emit IIgnitionParticipantSoulbound.IgnitionParticipantSoulboundMinted(
            _beneficiary, _user, IIgnitionParticipantSoulbound.TokenId(_tokenId), gridTileId
        );
        vm.prank(_user);
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId(_tokenId),
            _beneficiary,
            merkleProof,
            address(mockTrueWhitelistProvider),
            bytes(""),
            bytes(""),
            gridTileId
        );

        assertEq(soulboundToken.balanceOf(_beneficiary, _tokenId), 1);
        assertEq(soulboundToken.gridTileId(_beneficiary), gridTileId);
        assertEq(soulboundToken.isGridTileIdAssigned(gridTileId), true);

        vm.expectRevert(IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__TokenIsSoulbound.selector);
        vm.prank(_beneficiary);
        soulboundToken.safeTransferFrom(_beneficiary, _to, _tokenId, 1, bytes(""));

        assertEq(soulboundToken.balanceOf(_beneficiary, _tokenId), 1);
        assertEq(soulboundToken.balanceOf(_to, _tokenId), 0);
    }
}
