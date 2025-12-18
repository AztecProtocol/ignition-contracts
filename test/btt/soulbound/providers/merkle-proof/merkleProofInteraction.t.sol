// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {SoulboundBase} from "../../SoulboundBase.t.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {TestMerkleTreeGetters} from "test/merkle-tree/merkle_tree_getters.sol";
import {ERC1155Holder} from "@oz/token/ERC1155/utils/ERC1155Holder.sol";

contract MerkleProofInteraction is SoulboundBase, TestMerkleTreeGetters, ERC1155Holder {
    function setUp() public override {
        super.setUp();
        initTrees();
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheUserDoesNotHaveAValidMerkleProof(
        uint8 _index,
        uint8 _treeType,
        uint8 _tokenId,
        address _beneficiary
    ) external {
        // It reverts with {MerkleProofInvalid()}

        _index = boundTreeIndex(_index);
        _treeType = boundTree(_treeType);
        _tokenId = boundTokenId(_tokenId);
        assumeAddress(_beneficiary);

        // User has a valid proof for the wrong address
        address addr = getAddress(_index, TestMerkleTreeGetters.MerkleTreeType(_treeType));
        bytes32[] memory proof = getMerkleProof(_index + 1, TestMerkleTreeGetters.MerkleTreeType(_treeType));

        vm.expectRevert(
            abi.encodeWithSelector(
                IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__MerkleProofInvalid.selector
            )
        );
        vm.prank(addr);
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId(_tokenId),
            _beneficiary,
            proof,
            address(mockTrueWhitelistProvider),
            bytes(""),
            bytes(""),
            gridTileId
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheUserHasAValidMerkleProof(uint8 _index, uint8 _tokenId, address _beneficiary) external {
        // It does not revert

        _index = boundTreeIndex(_index);
        _tokenId = boundTokenId(_tokenId);
        assumeAddress(_beneficiary);

        (address addr, bytes32[] memory proof) = getAddressAndProof(_index, TestMerkleTreeGetters.MerkleTreeType(_tokenId));

        vm.expectEmit(true, true, true, true, address(soulboundToken));
        emit IIgnitionParticipantSoulbound.IgnitionParticipantSoulboundMinted(
            _beneficiary, addr, IIgnitionParticipantSoulbound.TokenId(_tokenId), gridTileId
        );
        vm.prank(addr);
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId(_tokenId),
            _beneficiary,
            proof,
            address(mockTrueWhitelistProvider),
            bytes(""),
            bytes(""),
            gridTileId
        );
    }
}
