// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Test, stdStorage, StdStorage} from "forge-std/Test.sol";
import {GenesisSequencerSaleBase} from "../GenesisSequencerSaleBase.t.sol";
import {IGenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";
import {TestMerkleTreeGetters} from "test/merkle-tree/merkle_tree_getters.sol";

// Atp
import {ILATP} from "@atp/atps/linear/ILATP.sol";
import {ATPType} from "@atp/atps/base/IATP.sol";
import {RevokableParams} from "@atp/atps/linear/ILATP.sol";
import {LockLib} from "@atp/libraries/LockLib.sol";

contract Purchase is GenesisSequencerSaleBase, TestMerkleTreeGetters {
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

    function test_WhenTheSaleIsNotActive() external whenSaleIsNotActive {
        // It reverts
        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__SaleNotEnabled.selector);
        genesisSequencerSale.purchase(beneficiary, "");
    }

    function test_WhenTheSaleHasNotStarted() external {
        // It reverts
        isSaleActive(true);
        hasSaleStarted(false);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__SaleNotStarted.selector);
        genesisSequencerSale.purchase(beneficiary, "");
    }

    function test_WhenTheSaleHasEnded() external givenSaleHasStarted {
        // It reverts
        hasSaleEnded(true);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__SaleHasEnded.selector);
        genesisSequencerSale.purchase(beneficiary, "");
    }

    function test_WhenThePurchaseCountIsZero() external givenSaleHasStarted {
        // It reverts

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__IncorrectETH.selector);
        genesisSequencerSale.purchase(beneficiary, "");
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheMaxPurchasesPerAddressIsReached(uint8 _treeIndex) external givenSaleHasStarted {
        // It reverts with {AlreadyPurchased()}
        initTrees();
        fundTokenSale();

        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        mintUserAlignedSoulboundToken(addr, _merkleProof);

        uint256 amount = pricePerLot * genesisSequencerSale.PURCHASES_PER_ADDRESS();
        vm.deal(addr, amount * 2);

        vm.prank(addr);
        genesisSequencerSale.purchase{value: amount}(beneficiary, "");

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

        mintUserAlignedSoulboundToken(addr, _merkleProof);

        // Deal less than the price per lot
        _amount = uint8(
            bound(
                uint256(_amount), 0, genesisSequencerSale.pricePerLot() * genesisSequencerSale.PURCHASES_PER_ADDRESS()
            )
        );

        vm.deal(addr, _amount);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__IncorrectETH.selector);
        vm.prank(addr);
        genesisSequencerSale.purchase{value: _amount}(beneficiary, "");
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheUserHasProvidedExcessEth(uint8 _treeIndex, uint256 _amount) external givenSaleHasStarted {
        // It reverts with {IncorrectETH()}
        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        mintUserAlignedSoulboundToken(addr, _merkleProof);

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
        genesisSequencerSale.purchase{value: _amount}(beneficiary, "");
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

        mintUserContributorSoulboundToken(addr, _merkleProof);

        uint256 amount = pricePerLot * genesisSequencerSale.PURCHASES_PER_ADDRESS();
        vm.deal(addr, amount);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__NoSoulboundToken.selector);
        vm.prank(addr);
        genesisSequencerSale.purchase{value: amount}(_beneficiary, "");
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

        mintUserContributorSoulboundToken(addr, _merkleProof);

        uint256 amount = pricePerLot * genesisSequencerSale.PURCHASES_PER_ADDRESS();
        vm.deal(addr, amount);

        vm.expectRevert();
        vm.prank(addr);
        genesisSequencerSale.purchase{value: amount}(beneficiary, "");
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenTheAddressScreeningFails(uint8 _treeIndex) external givenSaleHasStarted {
        // It reverts with {InsufficientBalance()}
        fundTokenSale();
        setSaleAddressScreeningFails();

        initTrees();
        _treeIndex = boundTreeIndex(_treeIndex);

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        mintUserAlignedSoulboundToken(addr, _merkleProof);

        uint256 amount = pricePerLot * genesisSequencerSale.PURCHASES_PER_ADDRESS();
        vm.deal(addr, amount);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__AddressScreeningFailed.selector);
        vm.prank(addr);
        genesisSequencerSale.purchase{value: amount}(beneficiary, "");
    }

    /// forge-config: default.fuzz.runs = 10
    function test_WhenAllRequirementsAreMet(uint8 _treeIndex) external givenSaleHasStarted {
        // It mints an ATP with the correct amount of tokens
        _treeIndex = boundTreeIndex(_treeIndex);

        // Fund token sale with many tokens
        fundTokenSale();
        // Set the root of the merkle trees in the whitelist contract
        initTrees();

        (address addr, bytes32[] memory _merkleProof) =
            getAddressAndProof(_treeIndex, TestMerkleTreeGetters.MerkleTreeType.GenesisSequencer);

        // Mint merkle whitelist token for the user
        mintUserAlignedSoulboundToken(addr, _merkleProof);

        uint256 purchaseCostInEth = genesisSequencerSale.getPurchaseCostInEth();
        vm.deal(addr, purchaseCostInEth);

        // Check the configuration of the ATP
        // Calaulate the ATP address
        address atpAddress = atpFactory.predictNCATPAddress(
            beneficiary,
            genesisSequencerSale.TOKEN_LOT_SIZE() * genesisSequencerSale.PURCHASES_PER_ADDRESS(),
            RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
        );

        uint256 saleBalanceBefore = saleToken.balanceOf(address(genesisSequencerSale));

        vm.expectEmit(true, true, true, true, address(genesisSequencerSale));
        emit IGenesisSequencerSale.SaleTokensPurchased(beneficiary, addr, atpAddress, purchaseCostInEth);
        vm.prank(addr);
        genesisSequencerSale.purchase{value: purchaseCostInEth}(beneficiary, "");

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
        assertEq(atp.getBeneficiary(), beneficiary);
        assertEq(
            atp.getAllocation(), genesisSequencerSale.TOKEN_LOT_SIZE() * genesisSequencerSale.PURCHASES_PER_ADDRESS()
        );
        assertEq(atp.getIsRevokable(), false);

        assertEq(atp.getOperator(), address(0));
        assertEq(address(atp.getToken()), address(saleToken));
        assertEq(uint8(atp.getType()), uint8(ATPType.NonClaim));

        // Update operator
        vm.prank(beneficiary);
        atp.updateStakerOperator(beneficiary);

        assertEq(atp.getOperator(), beneficiary);
    }
}
