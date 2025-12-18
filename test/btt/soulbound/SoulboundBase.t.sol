// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {MockTrueWhitelistProvider, MockFalseWhitelistProvider} from "test/mocks/MockWhitelistProvider.sol";
import {IgnitionParticipantSoulbound} from "src/soulbound/IgnitionParticipantSoulbound.sol";

import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {IWhitelistProvider} from "src/soulbound/providers/IWhitelistProvider.sol";
import {TestMerkleTreeGetters} from "test/merkle-tree/merkle_tree_getters.sol";

contract SoulboundBase is Test {
    // We are running with a super small tree right now for testing purposes
    uint256 public constant TREE_SIZE = 8;

    IWhitelistProvider public mockTrueWhitelistProvider;
    IWhitelistProvider public mockFalseWhitelistProvider;

    IWhitelistProvider public mockTrueScreeningProvider;
    IWhitelistProvider public mockFalseScreeningProvider;

    IgnitionParticipantSoulbound public soulboundToken;

    uint256 public gridTileId;

    function setUp() public virtual {
        mockTrueWhitelistProvider = new MockTrueWhitelistProvider();
        mockFalseWhitelistProvider = new MockFalseWhitelistProvider();

        mockTrueScreeningProvider = new MockTrueWhitelistProvider();
        mockFalseScreeningProvider = new MockFalseWhitelistProvider();

        address[] memory whitelistProviders = new address[](2);
        whitelistProviders[0] = address(mockTrueWhitelistProvider);
        whitelistProviders[1] = address(mockFalseWhitelistProvider);

        soulboundToken = new IgnitionParticipantSoulbound(
            address(0), whitelistProviders, bytes32(0), bytes32(0), address(mockTrueScreeningProvider), ""
        );

        gridTileId = 1;
    }

    function boundTreeIndex(uint8 _treeIndex) public pure returns (uint8) {
        return uint8(bound(_treeIndex, 0, TREE_SIZE));
    }

    function boundTree(uint8 _treeIndex) public pure returns (uint8) {
        // Must be the trees that require
        return uint8(bound(_treeIndex, 0, uint256(TestMerkleTreeGetters.MerkleTreeType.Contributor)));
    }

    function boundTokenId(uint8 _tokenId) public pure returns (uint8) {
        return uint8(bound(_tokenId, 0, uint256(IIgnitionParticipantSoulbound.TokenId.GENERAL) - 1));
    }

    function initTrees() public {
        setGenesisSequencerMerkleRootFromFile();
        setContributorMerkleRootFromFile();
    }

    function setGenesisSequencerMerkleRootFromFile() public {
        bytes32 _merkleRoot = vm.parseBytes32(vm.readFile("merkle-tree/test-utils/test-outputs/genesis_sequencer_root.txt"));
        soulboundToken.setGenesisSequencerMerkleRoot(_merkleRoot);
    }

    function setContributorMerkleRootFromFile() public {
        bytes32 _merkleRoot = vm.parseBytes32(vm.readFile("merkle-tree/test-utils/test-outputs/contributor_root.txt"));
        soulboundToken.setContributorMerkleRoot(_merkleRoot);
    }

    function setMockTrueScreeningProvider() public {
        soulboundToken.setAddressScreeningProvider(address(mockTrueScreeningProvider));
    }

    function setMockFalseScreeningProvider() public {
        soulboundToken.setAddressScreeningProvider(address(mockFalseScreeningProvider));
    }

    function setGenesisSequencerMerkleRoot(bytes32 _merkleRoot) public {
        soulboundToken.setGenesisSequencerMerkleRoot(_merkleRoot);
    }

    function setContributorMerkleRoot(bytes32 _merkleRoot) public {
        soulboundToken.setContributorMerkleRoot(_merkleRoot);
    }

    function assumeAddress(address _address) public view {
        vm.assume(
            _address != address(0) && _address != address(this) && _address != address(soulboundToken)
                && _address != address(mockTrueWhitelistProvider) && _address != address(mockFalseWhitelistProvider)
                && _address != address(vm)
        );
        vm.assume(_address.code.length == 0);
    }
}
