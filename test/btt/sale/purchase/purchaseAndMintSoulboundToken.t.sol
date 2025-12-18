// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Test, stdStorage, StdStorage} from "forge-std/Test.sol";
import {GenesisSequencerSaleBase} from "../GenesisSequencerSaleBase.t.sol";
import {IGenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IgnitionParticipantSoulbound.sol";
import {TestMerkleTreeGetters} from "test/merkle-tree/merkle_tree_getters.sol";

// Atp
import {ILATP} from "@atp/atps/linear/ILATP.sol";
import {ATPType} from "@atp/atps/base/IATP.sol";
import {RevokableParams} from "@atp/atps/linear/ILATP.sol";
import {LockLib} from "@atp/libraries/LockLib.sol";

contract PurchaseAndMintSoulboundToken is GenesisSequencerSaleBase, TestMerkleTreeGetters {
    using stdStorage for StdStorage;

    address public beneficiary = makeAddr("beneficiary");

    function setUp() public override {
        super.setUp();
    }

    modifier whenSaleIsNotActive() {
        isSaleActive(false);

        _;
    }

    modifier givenSaleHasStarted() {
        isSaleActive(true);
        hasSaleStarted(true);
        _;
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheSaleIsNotActive(uint8 _treeIndex) external whenSaleIsNotActive {
        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        // It reverts
        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__SaleNotEnabled.selector);
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken(
            beneficiary, merkleProof, address(mockTrueWhitelistProvider), "", "", "", gridTileId
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheSaleHasNotStarted(uint8 _treeIndex) external {
        // It reverts
        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);

        isSaleActive(true);
        hasSaleStarted(false);
        setAddressScreeningPasses();

        (address addr, bytes32[] memory merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__SaleNotStarted.selector);
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken(
            beneficiary, merkleProof, address(mockTrueWhitelistProvider), "", "", "", gridTileId
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheSaleHasEnded(uint8 _treeIndex) external givenSaleHasStarted {
        // It reverts
        hasSaleEnded(true);

        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__SaleHasEnded.selector);
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken(
            beneficiary, merkleProof, address(mockTrueWhitelistProvider), "", "", "", gridTileId
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheETHProvidedIsZero(uint8 _treeIndex) external givenSaleHasStarted {
        // It reverts
        initTrees();
        fundTokenSale();

        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__IncorrectETH.selector);
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken(
            beneficiary, merkleProof, address(mockTrueWhitelistProvider), "", "", "", gridTileId
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheMaxPurchasesPerAddressIsReached(uint8 _treeIndex) external givenSaleHasStarted {
        // It reverts with {AlreadyPurchased()}
        initTrees();
        fundTokenSale();

        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        uint256 amount = pricePerLot * genesisSequencerSale.PURCHASES_PER_ADDRESS();
        vm.deal(addr, amount * 2);

        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken{
            value: amount
        }(beneficiary, _merkleProof, address(mockTrueWhitelistProvider), "", "", "", gridTileId);

        // Check the address has purchased
        assertEq(genesisSequencerSale.hasPurchased(addr), true);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__AlreadyPurchased.selector);
        vm.prank(addr);
        genesisSequencerSale.purchase{value: amount}(beneficiary, "");
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheUserHasNotProvidedEnoughEth(uint8 _treeIndex, uint256 _amount) external givenSaleHasStarted {
        // It reverts with {IncorrectETH()}
        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        // Deal less than the price per lot
        _amount = uint8(
            bound(
                uint256(_amount), 0, genesisSequencerSale.pricePerLot() * genesisSequencerSale.PURCHASES_PER_ADDRESS()
            )
        );

        vm.deal(addr, _amount);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__IncorrectETH.selector);
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken{
            value: _amount
        }(beneficiary, _merkleProof, address(mockTrueWhitelistProvider), "", "", "", gridTileId);
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheUserHasProvidedExcessEth(uint8 _treeIndex, uint256 _amount) external givenSaleHasStarted {
        // It reverts with {IncorrectETH()}
        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        // Deal more than the price per lot
        _amount = uint8(
            bound(
                uint256(_amount),
                genesisSequencerSale.pricePerLot() * genesisSequencerSale.PURCHASES_PER_ADDRESS(),
                genesisSequencerSale.pricePerLot() * genesisSequencerSale.PURCHASES_PER_ADDRESS() * 2
            )
        );

        vm.deal(addr, _amount);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__IncorrectETH.selector);
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken{
            value: _amount
        }(beneficiary, _merkleProof, address(mockTrueWhitelistProvider), "", "", "", gridTileId);
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheUserHasAnContributorSoulboundToken(uint8 _treeIndex, address _beneficiary)
        external
        givenSaleHasStarted
    {
        // It reverts with {InvalidTokenId()}

        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.Contributor);

        uint256 amount = pricePerLot * genesisSequencerSale.PURCHASES_PER_ADDRESS();
        vm.deal(addr, amount);

        vm.expectRevert(IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__MerkleProofInvalid.selector);
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken{
            value: amount
        }(_beneficiary, _merkleProof, address(mockTrueWhitelistProvider), "", "", "", gridTileId);
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheSaleTokenBalanceIsNotEnoughToFulfilTheUserOrder(uint8 _treeIndex)
        external
        givenSaleHasStarted
    {
        // It reverts with {InsufficientBalance()}
        uint256 lessThanPurchaseAmount = genesisSequencerSale.TOKEN_LOT_SIZE();
        fundTokenSale(lessThanPurchaseAmount);

        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.Contributor);

        uint256 amount = pricePerLot * genesisSequencerSale.PURCHASES_PER_ADDRESS();
        vm.deal(addr, amount);

        vm.expectRevert();
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken{
            value: amount
        }(beneficiary, _merkleProof, address(mockTrueWhitelistProvider), "", "", "", gridTileId);
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenIdentityProviderFails(uint8 _treeIndex, address _beneficiary) external givenSaleHasStarted {
        // It reverts

        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__InvalidAuth.selector,
                address(mockFalseWhitelistProvider)
            )
        );
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken(
            _beneficiary, _merkleProof, address(mockFalseWhitelistProvider), "", "", "", gridTileId
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenAddressScreeningFails(uint8 _treeIndex) external givenSaleHasStarted {
        // It reverts
        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);
        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        setAddressScreeningFails();

        vm.expectRevert(
            abi.encodeWithSelector(
                IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__InvalidAuth.selector,
                address(mockFalseWhitelistProvider)
            )
        );
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken(
            addr, _merkleProof, address(mockFalseWhitelistProvider), "", "", "", gridTileId
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenUserHasAlreadyHasNft(uint8 _treeIndex) external givenSaleHasStarted {
        // It reverts
        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);
        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        mintUserAlignedSoulboundToken(addr, _merkleProof);

        vm.expectRevert(
            abi.encodeWithSelector(IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__AlreadyMinted.selector)
        );
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken(
            addr, _merkleProof, address(mockTrueWhitelistProvider), "", "", "", gridTileId
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenWhitelistProviderIsNotRegistered(uint8 _treeIndex, address _whitelistProvider)
        external
        givenSaleHasStarted
    {
        // It reverts
        vm.assume(_whitelistProvider != address(mockTrueWhitelistProvider));
        vm.assume(_whitelistProvider != address(mockFalseWhitelistProvider));

        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__InvalidAuth.selector, _whitelistProvider
            )
        );
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken(
            addr, _merkleProof, _whitelistProvider, "", "", "", gridTileId
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhengridTileIdHasAlreadyBeenMinted(uint8 _treeIndex, address _beneficiary, address _otherMinter)
        external
        givenSaleHasStarted
    {
        // It reverts

        vm.assume(_beneficiary != address(0));
        vm.assume(_beneficiary != address(this));
        vm.assume(_beneficiary != address(genesisSequencerSale));
        vm.assume(_beneficiary != address(soulboundToken));
        vm.assume(_otherMinter != address(0));
        vm.assume(_otherMinter != address(this));
        vm.assume(_otherMinter != address(genesisSequencerSale));
        vm.assume(_otherMinter != address(soulboundToken));
        vm.assume(_otherMinter != address(atpRegistry));

        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        // Mint the addr with the grid token id
        vm.prank(FOUNDATION_ADDRESS);
        soulboundToken.adminMint(_otherMinter, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, gridTileId);

        vm.expectRevert(
            abi.encodeWithSelector(
                IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__GridTileAlreadyAssigned.selector
            )
        );
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken(
            addr, _merkleProof, address(mockTrueWhitelistProvider), "", "", "", gridTileId
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenGridTileIdHasAlreadyBeenMinted(uint8 _treeIndex, address _beneficiary, address _otherMinter)
        external
        givenSaleHasStarted
    {
        // It reverts

        vm.assume(_beneficiary != address(0));
        vm.assume(_beneficiary != address(this));
        vm.assume(_beneficiary != address(genesisSequencerSale));
        vm.assume(_beneficiary != address(soulboundToken));
        vm.assume(_otherMinter != address(0));
        vm.assume(_otherMinter != address(this));
        vm.assume(_otherMinter != address(genesisSequencerSale));
        vm.assume(_otherMinter != address(soulboundToken));
        vm.assume(_otherMinter != address(atpRegistry));

        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        // Mint the addr with the grid token id
        vm.prank(FOUNDATION_ADDRESS);
        soulboundToken.adminMint(_otherMinter, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, gridTileId);

        vm.expectRevert(
            abi.encodeWithSelector(
                IIgnitionParticipantSoulbound.IgnitionParticipantSoulbound__GridTileAlreadyAssigned.selector
            )
        );
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken(
            addr, _merkleProof, address(mockTrueWhitelistProvider), "", "", "", gridTileId
        );
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenAtpBeneficiaryScreeningFails(uint8 _treeIndex, address _atpBeneficiary)
        external
        givenSaleHasStarted
    {
        // It reverts

        vm.assume(_atpBeneficiary != address(0));
        vm.assume(_atpBeneficiary != address(this));
        vm.assume(_atpBeneficiary != address(genesisSequencerSale));
        vm.assume(_atpBeneficiary != address(soulboundToken));

        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        uint256 purchaseCostInEth = genesisSequencerSale.getPurchaseCostInEth();
        vm.deal(addr, purchaseCostInEth);

        setSaleAddressScreeningFails();

        vm.expectRevert(
            abi.encodeWithSelector(IGenesisSequencerSale.GenesisSequencerSale__AddressScreeningFailed.selector)
        );
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken{
            value: purchaseCostInEth
        }(_atpBeneficiary, _merkleProof, address(mockTrueWhitelistProvider), "", "", "", gridTileId);
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenAllRequirementsAreMet(uint8 _treeIndex, address _beneficiary) external givenSaleHasStarted {
        // It mints an ATP with the correct amount of tokens
        _treeIndex = boundTreeIndex(_treeIndex);

        vm.assume(_beneficiary != address(0));
        vm.assume(_beneficiary != address(this));
        vm.assume(_beneficiary != address(genesisSequencerSale));
        vm.assume(_beneficiary != address(soulboundToken));

        // Fund token sale with many tokens
        fundTokenSale();
        // Set the root of the merkle trees in the whitelist contract
        initTrees();

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        uint256 purchaseCostInEth = genesisSequencerSale.getPurchaseCostInEth();
        vm.deal(addr, purchaseCostInEth);

        // Check the configuration of the ATP
        // Calaulate the ATP address
        address atpAddress = atpFactory.predictNCATPAddress(
            _beneficiary,
            genesisSequencerSale.TOKEN_LOT_SIZE() * genesisSequencerSale.PURCHASES_PER_ADDRESS(),
            RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
        );

        uint256 saleBalanceBefore = saleToken.balanceOf(address(genesisSequencerSale));

        setAddressScreeningPasses();

        vm.expectEmit(true, true, true, true, address(genesisSequencerSale));
        emit IGenesisSequencerSale.SaleTokensPurchased(_beneficiary, addr, atpAddress, purchaseCostInEth);
        vm.prank(addr);
        genesisSequencerSale.purchaseAndMintSoulboundToken{
            value: purchaseCostInEth
        }(_beneficiary, _merkleProof, address(mockTrueWhitelistProvider), "", "", "", gridTileId);

        // Check that the addr has the soulbound token

        // Assert the sale token balance has decreased by the amount of the purchase
        uint256 saleBalanceAfter = saleToken.balanceOf(address(genesisSequencerSale));
        assertEq(
            saleBalanceBefore - saleBalanceAfter,
            genesisSequencerSale.TOKEN_LOT_SIZE() * genesisSequencerSale.PURCHASES_PER_ADDRESS()
        );

        assertEq(address(genesisSequencerSale).balance, purchaseCostInEth);
        assertEq(genesisSequencerSale.hasPurchased(addr), true);

        // Check created ATP is configured correctly
        ILATP atp = ILATP(atpAddress);
        assertEq(atp.getBeneficiary(), _beneficiary);
        assertEq(
            atp.getAllocation(), genesisSequencerSale.TOKEN_LOT_SIZE() * genesisSequencerSale.PURCHASES_PER_ADDRESS()
        );
        assertEq(atp.getIsRevokable(), false);

        assertEq(atp.getOperator(), address(0));
        assertEq(address(atp.getToken()), address(saleToken));
        assertEq(uint8(atp.getType()), uint8(ATPType.NonClaim));

        // Update operator
        vm.prank(_beneficiary);
        atp.updateStakerOperator(_beneficiary);

        assertEq(atp.getOperator(), _beneficiary);
    }
}
