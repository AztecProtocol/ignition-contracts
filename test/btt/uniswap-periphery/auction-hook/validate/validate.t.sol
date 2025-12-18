// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {AztecAuctionHook, IAztecAuctionHook} from "src/uniswap-periphery/AuctionHook.sol";
import {IgnitionParticipantSoulbound} from "src/soulbound/IgnitionParticipantSoulbound.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {IWhitelistProvider} from "src/soulbound/providers/IWhitelistProvider.sol";
import {MockTrueWhitelistProvider, MockFalseWhitelistProvider} from "test/mocks/MockWhitelistProvider.sol";

// Mocks
import {MockAuction} from "test/mocks/uniswap-periphery/MockAuction.sol";

// Uniswap
import {MockERC20} from "test/mocks/MockERC20.sol";
import {IContinuousClearingAuction, AuctionParameters} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";

import {Test} from "forge-std/Test.sol";

import {console} from "forge-std/console.sol";

contract AztecAuctionHookValidate is Test {
    AztecAuctionHook public auctionHook;
    IContinuousClearingAuction public auction;
    IgnitionParticipantSoulbound public soulboundToken;
    MockERC20 public mockToken;

    IWhitelistProvider public trueWhitelistProvider;
    IWhitelistProvider public falseWhitelistProvider;
    uint256 public gridTileId;

    uint128 public constant TOTAL_SUPPLY = 100_000_000 ether;

    function setUp() public {
        trueWhitelistProvider = new MockTrueWhitelistProvider();
        falseWhitelistProvider = new MockFalseWhitelistProvider();

        address[] memory identityProviders = new address[](1);
        identityProviders[0] = address(trueWhitelistProvider);

        soulboundToken = new IgnitionParticipantSoulbound(
            address(1), identityProviders, bytes32(0), bytes32(0), address(trueWhitelistProvider), ""
        );

        auction = IContinuousClearingAuction(address(new MockAuction()));
    }

    // Helpers

    function _assumeAddress(address _address) public view {
        vm.assume(_address != address(0) && _address.code.length == 0);
    }

    function setClearingPrice(uint256 _clearingPrice) public {
        MockAuction(address(auction)).setClearingPrice(_clearingPrice);
    }

    function mintGenesisSoulbound(address _user) public {
        soulboundToken.adminMint(address(_user), IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, gridTileId++);
    }

    function mintContributorSoulbound(address _user) public {
        soulboundToken.adminMint(address(_user), IIgnitionParticipantSoulbound.TokenId.CONTRIBUTOR, gridTileId++);
    }

    function mintGeneralSoulbound(address _user) public {
        soulboundToken.adminMint(address(_user), IIgnitionParticipantSoulbound.TokenId.GENERAL, gridTileId++);
    }

    // Test modifiers

    modifier givenTheContributorPeriodHasNotEnded() {
        auctionHook = new AztecAuctionHook(soulboundToken, block.number + 100);
        auctionHook.setAuction(auction);
        _;
    }

    modifier givenTheContributorPeriodHasEnded() {
        auctionHook = new AztecAuctionHook(soulboundToken, block.number + 100);
        auctionHook.setAuction(auction);
        vm.roll(block.number + 100);
        _;
    }

    // Tests

    function test_GivenTheContributorPeriodHasNotEnded_WhenTheSenderIsAGenesisSequencer(address _user)
        public
        givenTheContributorPeriodHasNotEnded
    {
        _assumeAddress(_user);
        mintGenesisSoulbound(_user);

        // Does not revert
        vm.prank(address(auction));
        auctionHook.validate(0, 0, _user, _user, "");
    }

    function test_GivenTheContributorPeriodHasNotEnded_WhenTheSenderIsAContributor(address _user)
        public
        givenTheContributorPeriodHasNotEnded
    {
        _assumeAddress(_user);
        mintContributorSoulbound(_user);

        // Does not revert
        vm.prank(address(auction));
        auctionHook.validate(0, 0, _user, _user, "");
    }

    function test_GivenTheContributorPeriodHasNotEnded_WhenTheSenderIsNotAContributor(address _user)
        public
        givenTheContributorPeriodHasNotEnded
    {
        _assumeAddress(_user);
        mintGeneralSoulbound(_user);

        // Reverts
        vm.expectRevert(abi.encodeWithSelector(IAztecAuctionHook.AztecAuctionHook__NotContributor.selector));
        vm.prank(address(auction));
        auctionHook.validate(0, 0, _user, _user, "");
    }

    function test_GivenTheContributorPeriodHasNotEnded_WhenTheSenderDoesNotHaveASoulboundToken(address _user)
        public
        givenTheContributorPeriodHasNotEnded
    {
        _assumeAddress(_user);

        // Reverts
        vm.expectRevert(abi.encodeWithSelector(IAztecAuctionHook.AztecAuctionHook__NotContributor.selector));
        vm.prank(address(auction));
        auctionHook.validate(0, 0, _user, _user, "");
    }

    function test_GivenTheContributorPeriodHasEnded_WhenTheSenderIsAGenesisSequencer(address _user)
        public
        givenTheContributorPeriodHasEnded
    {
        _assumeAddress(_user);
        mintGenesisSoulbound(_user);

        // Does not revert
        vm.prank(address(auction));
        auctionHook.validate(0, 0, _user, _user, "");
    }

    function test_GivenTheContributorPeriodHasEnded_WhenTheSenderIsAContributor(address _user)
        public
        givenTheContributorPeriodHasEnded
    {
        _assumeAddress(_user);
        mintContributorSoulbound(_user);

        // Does not revert
        vm.prank(address(auction));
        auctionHook.validate(0, 0, _user, _user, "");
    }

    function test_GivenTheContributorPeriodHasEnded_WhenTheSenderIsNotAContributor(address _user)
        public
        givenTheContributorPeriodHasEnded
    {
        _assumeAddress(_user);
        mintGeneralSoulbound(_user);

        // Does not revert
        vm.prank(address(auction));
        auctionHook.validate(0, 0, _user, _user, "");
    }

    function test_GivenTheContributorPeriodHasEnded_WhenTheSenderDoesNotHaveASoulboundToken(address _user)
        public
        givenTheContributorPeriodHasEnded
    {
        _assumeAddress(_user);

        // Reverts
        vm.expectRevert(abi.encodeWithSelector(IAztecAuctionHook.AztecAuctionHook__NotSoulbound.selector));
        vm.prank(address(auction));
        auctionHook.validate(0, 0, _user, _user, "");
    }

    function test_GivenTheSenderIsNotTheAuction(address _user) public givenTheContributorPeriodHasNotEnded {
        vm.assume(_user != address(auction));

        // Reverts
        vm.expectRevert(abi.encodeWithSelector(IAztecAuctionHook.AztecAuctionHook__NotAuction.selector));
        auctionHook.validate(0, 0, _user, _user, "");
    }

    function test_GivenTheSenderIsTheAuction_WhenTheBidIsExactIn(address _user, uint128 _amount, uint256 _maxPrice)
        public
        givenTheContributorPeriodHasNotEnded
    {
        // It should allow bids under the max purchase limit

        _assumeAddress(_user);
        mintGenesisSoulbound(_user);

        vm.assume(_amount <= auctionHook.MAX_PURCHASE_LIMIT());

        // Does not revert
        vm.prank(address(auction));
        auctionHook.validate(_maxPrice, uint128(_amount), _user, _user, "");
    }

    function test_GivenTheSenderIsTheAuction_WhenTheBidIsExactIn_AndTheBidIsOverTheMaxPurchaseLimit(
        address _user,
        uint128 _amount,
        uint256 _maxPrice
    ) public givenTheContributorPeriodHasNotEnded {
        // It should not allow the bid / it reverts
        _assumeAddress(_user);
        mintGenesisSoulbound(_user);

        vm.assume(_amount > auctionHook.MAX_PURCHASE_LIMIT());

        // Does not revert
        vm.prank(address(auction));
        vm.expectRevert(abi.encodeWithSelector(IAztecAuctionHook.AztecAuctionHook__MaxPurchaseLimitExceeded.selector));
        auctionHook.validate(_maxPrice, uint128(_amount), _user, _user, "");
    }

    function test_GivenTheSenderIsTheAuction_WhenTheBidIsExactIn_AndMultipleBidsAreMade_AndTheBidIsOverTheMaxPurchaseLimit(
        address _user,
        uint8 _numberOfBids,
        uint128 _amount,
        uint256 _maxPrice
    ) public givenTheContributorPeriodHasNotEnded {
        // It should not allow the bid / it reverts

        _assumeAddress(_user);
        mintGenesisSoulbound(_user);

        vm.assume(_numberOfBids > 0);
        vm.assume(_amount > _numberOfBids);
        vm.assume(_amount > auctionHook.MAX_PURCHASE_LIMIT());

        // split the amount into the number of bids
        uint128[] memory amounts = new uint128[](_numberOfBids);
        uint128 amountPerBid = _amount / _numberOfBids;
        for (uint8 i = 0; i < _numberOfBids; i++) {
            amounts[i] = amountPerBid;
        }

        uint256 totalBid = 0;
        for (uint8 i = 0; i < _numberOfBids; i++) {
            totalBid += amounts[i];
            if (totalBid > auctionHook.MAX_PURCHASE_LIMIT()) {
                vm.expectRevert(
                    abi.encodeWithSelector(IAztecAuctionHook.AztecAuctionHook__MaxPurchaseLimitExceeded.selector)
                );
            }
            vm.prank(address(auction));
            auctionHook.validate(_maxPrice, amounts[i], _user, _user, "");
        }
    }

    function test_GivenTheSenderIsTheAuction_WhenTheBidIsExactIn_AndMultipleBidsAreMade_AndTheBidIsUnderTheMaxPurchaseLimit(
        address _user,
        uint8 _numberOfBids,
        uint128 _amount,
        uint256 _maxPrice
    ) public givenTheContributorPeriodHasNotEnded {
        // It should allow the bid / it does not revert

        _assumeAddress(_user);
        mintGenesisSoulbound(_user);

        vm.assume(_numberOfBids > 0);
        vm.assume(_amount > _numberOfBids);
        vm.assume(_amount > auctionHook.MAX_PURCHASE_LIMIT());

        // split the amount into the number of bids
        uint128[] memory amounts = new uint128[](_numberOfBids);
        uint128 amountPerBid = _amount / _numberOfBids;
        for (uint8 i = 0; i < _numberOfBids; i++) {
            amounts[i] = amountPerBid;
        }

        uint256 totalBid = 0;
        for (uint8 i = 0; i < _numberOfBids; i++) {
            totalBid += amounts[i];
            if (totalBid > auctionHook.MAX_PURCHASE_LIMIT()) {
                vm.expectRevert(
                    abi.encodeWithSelector(IAztecAuctionHook.AztecAuctionHook__MaxPurchaseLimitExceeded.selector)
                );
            }
            vm.prank(address(auction));
            auctionHook.validate(_maxPrice, amounts[i], _user, _user, "");
        }
    }

    function test_ownerNEQSender(address _owner, address _sender, uint128 _amount, uint256 _maxPrice)
        public
        givenTheContributorPeriodHasNotEnded
    {
        vm.assume(_owner != _sender);
        _assumeAddress(_owner);
        _assumeAddress(_sender);

        vm.expectRevert(abi.encodeWithSelector(IAztecAuctionHook.AztecAuctionHook__OwnerMustBeSender.selector));
        vm.prank(address(auction));
        auctionHook.validate(_maxPrice, _amount, _sender, _owner, "");
    }
}
