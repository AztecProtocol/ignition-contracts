// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {MockTrueWhitelistProvider, MockFalseWhitelistProvider} from "test/mocks/MockWhitelistProvider.sol";
import {SoulboundBase} from "./SoulboundBase.t.sol";
import {ERC1155Holder} from "@oz/token/ERC1155/utils/ERC1155Holder.sol";
import {TestMerkleTreeGetters} from "test/merkle-tree/merkle_tree_getters.sol";
import {PredicateMessage} from "@predicate/interfaces/IPredicateClient.sol";
import {IPredicateProvider} from "src/soulbound/providers/PredicateProvider.sol";

contract MintSoulboundToken is SoulboundBase, TestMerkleTreeGetters, ERC1155Holder {
    address public eligibilityProvider;

    function setUp() public override {
        super.setUp();
    }

    // given
    modifier givenTreesAreInitialized() {
        initTrees();
        _;
    }

    modifier givenBeneficiaryIsTheSameAsCaller() {
        _;
    }

    modifier givenBeneficiaryIsNotTheSameAsCaller() {
        _;
    }

    // when
    modifier whenTreesAreNotInitialized() {
        _;
    }

    modifier whenEligibilityProviderAccepts() {
        eligibilityProvider = address(mockTrueWhitelistProvider);
        _;
    }

    modifier whenEligibilityProviderRejects() {
        eligibilityProvider = address(mockFalseWhitelistProvider);
        _;
    }

    modifier whenScreeningProviderAccepts() {
        soulboundToken.setAddressScreeningProvider(address(mockTrueWhitelistProvider));
        _;
    }

    modifier whenScreeningProviderRejects() {
        soulboundToken.setAddressScreeningProvider(address(mockFalseWhitelistProvider));
        _;
    }

    function makePredicateAttestation() internal returns (PredicateMessage memory) {
        uint256 expireByTime = block.timestamp + 1 hours;
        address[] memory signerAddresses = new address[](1);
        signerAddresses[0] = makeAddr("predicateSigner");
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = bytes("");

        PredicateMessage memory message = PredicateMessage({
            taskId: "test", expireByTime: expireByTime, signerAddresses: signerAddresses, signatures: signatures
        });

        return message;
    }

    /// forge-config: default.fuzz.runs = 10
    function test_GivenTreesInitialized_GivenBeneficiaryIsCaller_WhenGridTileIdIsAlreadyTaken(
        uint8 _treeIndex,
        address _otherMinter
    ) public givenTreesAreInitialized givenBeneficiaryIsTheSameAsCaller {
        // it reverts with GridTokenAlreadyAssigned
        vm.assume(_otherMinter.code.length == 0);
        _treeIndex = boundTreeIndex(_treeIndex);
        (address addr, bytes32[] memory merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        soulboundToken.adminMint(_otherMinter, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, gridTileId);

        vm.expectRevert(
            abi.encodeWithSelector(
                IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__GridTileAlreadyAssigned.selector
            )
        );
        vm.prank(addr);
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
            addr,
            merkleProof,
            eligibilityProvider,
            bytes(""),
            bytes(""),
            gridTileId
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_GivenTreesInitialized_GivenBeneficiaryIsCaller_WhenEligibilityAccepts(uint8 _treeIndex)
        public
        givenTreesAreInitialized
        givenBeneficiaryIsTheSameAsCaller
        whenEligibilityProviderAccepts
    {
        // it mints

        _treeIndex = boundTreeIndex(_treeIndex);
        (address addr, bytes32[] memory merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        vm.expectEmit(true, true, true, true, address(soulboundToken));
        emit IIgnitionParticipantSoulbound.IgnitionParticipantSoulboundMinted(
            addr, addr, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, gridTileId
        );
        vm.prank(addr);
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
            addr,
            merkleProof,
            eligibilityProvider,
            bytes(""),
            bytes(""),
            gridTileId
        );

        assertEq(soulboundToken.balanceOf(addr, uint256(IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER)), 1);
    }

    /// forge-config: default.fuzz.runs = 10
    function test_GivenTreesInitialized_GivenBeneficiaryIsCaller_WhenEligibilityRejects(uint8 _treeIndex)
        public
        givenTreesAreInitialized
        givenBeneficiaryIsTheSameAsCaller
        whenEligibilityProviderRejects
    {
        // it reverts with InvalidAuth

        _treeIndex = boundTreeIndex(_treeIndex);
        (address addr, bytes32[] memory merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        vm.prank(addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__InvalidAuth.selector,
                address(mockFalseWhitelistProvider)
            )
        );
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
            addr,
            merkleProof,
            eligibilityProvider,
            bytes(""),
            bytes(""),
            gridTileId
        );

        assertEq(soulboundToken.balanceOf(addr, uint256(IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER)), 0);
    }

    /// forge-config: default.fuzz.runs = 10
    function test_GivenTreesInitialized_GivenBeneficiaryIsNotCaller_WhenGridTileIdIsAlreadyTaken(
        uint8 _treeIndex,
        address _otherMinter,
        address _beneficiary
    ) public givenTreesAreInitialized givenBeneficiaryIsNotTheSameAsCaller {
        // it reverts with GridTokenAlreadyAssigned
        _treeIndex = boundTreeIndex(_treeIndex);
        (address addr, bytes32[] memory merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        assumeAddress(_beneficiary);
        assumeAddress(_otherMinter);
        vm.assume(_beneficiary != addr);

        soulboundToken.adminMint(_otherMinter, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, gridTileId);

        vm.expectRevert(
            abi.encodeWithSelector(
                IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__GridTileAlreadyAssigned.selector
            )
        );
        vm.prank(addr);
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
            addr,
            merkleProof,
            eligibilityProvider,
            bytes(""),
            bytes(""),
            gridTileId
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_GivenTreesInitialized_GivenBeneficiaryIsNotCaller_WhenGridTileIdIsZero(
        uint8 _treeIndex,
        address _otherMinter,
        address _beneficiary
    ) public givenTreesAreInitialized givenBeneficiaryIsNotTheSameAsCaller {
        // it reverts with GridTokenAlreadyAssigned
        _treeIndex = boundTreeIndex(_treeIndex);
        (address addr, bytes32[] memory merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        assumeAddress(_beneficiary);
        assumeAddress(_otherMinter);
        vm.assume(_beneficiary != addr);

        vm.expectRevert(
            abi.encodeWithSelector(
                IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__GridTileIdCannotBeZero.selector
            )
        );
        vm.prank(addr);
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
            addr,
            merkleProof,
            eligibilityProvider,
            bytes(""),
            bytes(""),
            0
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_GivenTreesInitialized_GivenBeneficiaryIsNotCaller_WhenEligibilityAccepts(
        uint8 _treeIndex,
        address _beneficiary
    ) public givenTreesAreInitialized givenBeneficiaryIsNotTheSameAsCaller whenEligibilityProviderAccepts {
        // it mints

        _treeIndex = boundTreeIndex(_treeIndex);
        (address addr, bytes32[] memory merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        assumeAddress(_beneficiary);
        vm.assume(_beneficiary != addr);

        soulboundToken.setAddressScreeningProvider(address(mockTrueWhitelistProvider));

        PredicateMessage memory screeningAttestation = makePredicateAttestation();

        vm.expectEmit(true, true, true, true, address(soulboundToken));
        emit IIgnitionParticipantSoulbound.IgnitionParticipantSoulboundMinted(
            _beneficiary, addr, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, gridTileId
        );
        vm.prank(addr);
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
            _beneficiary,
            merkleProof,
            eligibilityProvider,
            bytes(""),
            abi.encode(screeningAttestation),
            gridTileId
        );

        assertEq(
            soulboundToken.balanceOf(_beneficiary, uint256(IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER)), 1
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_GivenTreesInitialized_GivenBeneficiaryIsNotCaller_WhenEligibilityRejects(
        uint8 _treeIndex,
        address _beneficiary
    ) public givenTreesAreInitialized givenBeneficiaryIsNotTheSameAsCaller whenEligibilityProviderRejects {
        // it reverts with InvalidAuth

        _treeIndex = boundTreeIndex(_treeIndex);
        (address addr, bytes32[] memory merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        assumeAddress(_beneficiary);
        vm.assume(_beneficiary != addr);

        soulboundToken.setAddressScreeningProvider(address(mockTrueWhitelistProvider));

        vm.prank(addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__InvalidAuth.selector,
                address(mockFalseWhitelistProvider)
            )
        );
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
            _beneficiary,
            merkleProof,
            eligibilityProvider,
            bytes(""),
            bytes(""),
            gridTileId
        );

        assertEq(
            soulboundToken.balanceOf(_beneficiary, uint256(IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER)), 0
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_GivenTreesInitialized_GivenBeneficiaryIsNotCaller_WhenScreeningAccepts(
        uint8 _treeIndex,
        address _beneficiary
    ) public givenTreesAreInitialized givenBeneficiaryIsNotTheSameAsCaller whenScreeningProviderAccepts {
        // it mints

        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        assumeAddress(_beneficiary);
        vm.assume(_beneficiary != addr);

        PredicateMessage memory screeningAttestation = makePredicateAttestation();

        vm.expectEmit(true, true, true, true, address(soulboundToken));
        emit IIgnitionParticipantSoulbound.IgnitionParticipantSoulboundMinted(
            _beneficiary, addr, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, gridTileId
        );
        vm.prank(addr);
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
            _beneficiary,
            merkleProof,
            address(mockTrueWhitelistProvider),
            bytes(""),
            abi.encode(screeningAttestation),
            gridTileId
        );

        assertEq(
            soulboundToken.balanceOf(_beneficiary, uint256(IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER)), 1
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_GivenTreesInitialized_GivenBeneficiaryIsNotCaller_WhenScreeningRejects(
        uint8 _treeIndex,
        address _beneficiary
    ) public givenTreesAreInitialized givenBeneficiaryIsNotTheSameAsCaller whenScreeningProviderRejects {
        // it reverts with InvalidAuth

        _treeIndex = boundTreeIndex(_treeIndex);
        (address addr, bytes32[] memory merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        assumeAddress(_beneficiary);
        vm.assume(_beneficiary != addr);

        PredicateMessage memory screeningAttestation = makePredicateAttestation();

        vm.prank(addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__InvalidAuth.selector,
                address(mockFalseWhitelistProvider)
            )
        );
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
            _beneficiary,
            merkleProof,
            address(mockTrueWhitelistProvider),
            bytes(""),
            abi.encode(screeningAttestation),
            gridTileId
        );

        assertEq(
            soulboundToken.balanceOf(_beneficiary, uint256(IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER)), 0
        );
    }

    function test_WhenGenesisSequencerTreeIsNotInitialized(address _caller, address _beneficiary)
        external
        whenTreesAreNotInitialized
        whenEligibilityProviderAccepts
    {
        assumeAddress(_caller);
        assumeAddress(_beneficiary);

        // it should revert with NoMerkleRootSet
        vm.expectRevert(
            abi.encodeWithSelector(IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__NoMerkleRootSet.selector)
        );
        vm.prank(_caller);
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
            _beneficiary,
            new bytes32[](0),
            eligibilityProvider,
            bytes(""),
            bytes(""),
            gridTileId
        );

        assertEq(
            soulboundToken.balanceOf(_beneficiary, uint256(IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER)), 0
        );
        assertEq(soulboundToken.balanceOf(_beneficiary, uint256(IIgnitionParticipantSoulbound.TokenId.CONTRIBUTOR)), 0);
        assertEq(soulboundToken.balanceOf(_beneficiary, uint256(IIgnitionParticipantSoulbound.TokenId.GENERAL)), 0);
    }

    function test_WhenContributorTreeIsNotInitialized(address _caller, address _beneficiary)
        external
        whenTreesAreNotInitialized
        whenEligibilityProviderAccepts
    {
        assumeAddress(_caller);
        assumeAddress(_beneficiary);

        // it should revert with NoMerkleRootSet
        vm.expectRevert(
            abi.encodeWithSelector(IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__NoMerkleRootSet.selector)
        );
        vm.prank(_caller);
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId.CONTRIBUTOR,
            _beneficiary,
            new bytes32[](0),
            eligibilityProvider,
            bytes(""),
            bytes(""),
            gridTileId
        );

        assertEq(
            soulboundToken.balanceOf(_beneficiary, uint256(IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER)), 0
        );
        assertEq(soulboundToken.balanceOf(_beneficiary, uint256(IIgnitionParticipantSoulbound.TokenId.CONTRIBUTOR)), 0);
        assertEq(soulboundToken.balanceOf(_beneficiary, uint256(IIgnitionParticipantSoulbound.TokenId.GENERAL)), 0);
    }

    function test_WhenBothTreesAreNotInitialized(address _caller, address _beneficiary)
        external
        whenTreesAreNotInitialized
    {
        assumeAddress(_caller);
        assumeAddress(_beneficiary);

        vm.prank(_caller);
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId.GENERAL,
            _beneficiary,
            new bytes32[](0),
            address(mockTrueWhitelistProvider),
            bytes(""),
            bytes(""),
            gridTileId
        );

        assertEq(soulboundToken.balanceOf(_beneficiary, uint256(IIgnitionParticipantSoulbound.TokenId.GENERAL)), 1);
    }
}
