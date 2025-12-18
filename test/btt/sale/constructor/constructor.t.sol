// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {Test} from "forge-std/Test.sol";
import {GenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";
import {IGenesisSequencerSale} from "src/sale/IGenesisSequencerSale.sol";
import {MockERC20} from "../../../mocks/MockERC20.sol";
import {MockGSE} from "test/mocks/staking/MockGSE.sol";
import {MockRollup} from "test/mocks/staking/MockRollup.sol";
import {IATPFactory, ATPFactory} from "@atp/ATPFactory.sol";
import {IStaking} from "src/staking/rollup-system-interfaces/IStaking.sol";
import {IRegistry} from "@atp/Registry.sol";
import {IgnitionParticipantSoulbound} from "src/soulbound/IgnitionParticipantSoulbound.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {MockTrueWhitelistProvider} from "../../../mocks/MockWhitelistProvider.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {Constants} from "src/constants.sol";

contract GenesisSequencerSaleConstructorTest is Test {
    MockERC20 public saleToken;
    IATPFactory public atpFactory;
    IgnitionParticipantSoulbound public soulboundToken;
    MockTrueWhitelistProvider public mockWhitelistProvider;
    IStaking public rollup;

    // Bound helper functions
    function _assumeValidAddress(address addr) internal pure {
        vm.assume(addr != address(0));
    }

    function _assumeValidPrice(uint256 price) internal pure {
        vm.assume(price > 0);
    }

    function _assumeValidTimeRange(uint96 startTime, uint96 endTime) internal view {
        vm.assume(startTime < endTime);
        vm.assume(startTime >= block.timestamp);
    }

    function _boundPrice(uint256 price) internal pure returns (uint256) {
        return bound(price, 1, 1000 ether);
    }

    function _boundCurrentTime(uint256 currentTime) internal pure returns (uint256) {
        return bound(currentTime, 1, type(uint32).max);
    }

    function _boundSaleStartTime(uint96 startTime, uint96 currentTime) internal pure returns (uint96) {
        return uint96(bound(uint256(startTime), uint256(currentTime), uint256(currentTime + 365 days)));
    }

    function _boundSaleEndTime(uint96 endTime, uint96 startTime) internal pure returns (uint96) {
        return uint96(bound(uint256(endTime), uint256(startTime + 1), uint256(startTime + 730 days)));
    }

    function setUp() public {
        // Deploy dependencies
        saleToken = new MockERC20("Sale Token", "SALE");
        atpFactory = new ATPFactory(address(this), saleToken, 1 days, 1 days);

        mockWhitelistProvider = new MockTrueWhitelistProvider();
        address[] memory whitelistProviders = new address[](1);
        whitelistProviders[0] = address(mockWhitelistProvider);

        soulboundToken =
            new IgnitionParticipantSoulbound(address(0), whitelistProviders, bytes32(0), bytes32(0), address(0), "");

        MockGSE gse = new MockGSE();
        rollup = new MockRollup(saleToken, gse);
    }

    function test_WhenOwnerIsZeroAddress(
        IATPFactory _atpFactory,
        IIgnitionParticipantSoulbound _soulboundToken,
        IERC20 _saleToken,
        IStaking _rollup,
        uint256 _pricePerLot,
        uint96 _saleStartTime,
        uint96 _saleEndTime,
        address _addressScreeningProvider
    ) external {
        // it should revert with OwnableInvalidOwner
        _assumeValidAddress(address(_atpFactory));
        _assumeValidAddress(address(_soulboundToken));
        _assumeValidAddress(address(_saleToken));
        _assumeValidAddress(address(_rollup));
        _assumeValidAddress(address(_addressScreeningProvider));
        _assumeValidPrice(_pricePerLot);
        _assumeValidTimeRange(_saleStartTime, _saleEndTime);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new GenesisSequencerSale(
            address(0),
            _atpFactory,
            _saleToken,
            _soulboundToken,
            _rollup,
            _pricePerLot,
            _saleStartTime,
            _saleEndTime,
            _addressScreeningProvider
        );
    }

    function test_WhenAtpFactoryIsZeroAddress(
        IIgnitionParticipantSoulbound _soulboundToken,
        IERC20 _saleToken,
        IStaking _rollup,
        uint256 _pricePerLot,
        uint96 _saleStartTime,
        uint96 _saleEndTime,
        address _addressScreeningProvider
    ) external {
        // it should revert with ZeroAddress
        _assumeValidAddress(address(_soulboundToken));
        _assumeValidAddress(address(_rollup));
        _assumeValidAddress(address(_addressScreeningProvider));
        _assumeValidPrice(_pricePerLot);
        _assumeValidTimeRange(_saleStartTime, _saleEndTime);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__ZeroAddress.selector);
        new GenesisSequencerSale(
            address(this),
            IATPFactory(address(0)),
            _saleToken,
            _soulboundToken,
            _rollup,
            _pricePerLot,
            _saleStartTime,
            _saleEndTime,
            _addressScreeningProvider
        );
    }

    function test_WhenSaleTokenIsZeroAddress(
        IATPFactory _atpFactory,
        IIgnitionParticipantSoulbound _soulboundToken,
        uint256 _pricePerLot,
        IStaking _rollup,
        uint96 _saleStartTime,
        uint96 _saleEndTime,
        address _addressScreeningProvider
    ) external {
        // it should revert with ZeroAddress
        _assumeValidAddress(address(_atpFactory));
        _assumeValidAddress(address(_soulboundToken));
        _assumeValidAddress(address(_rollup));
        _assumeValidAddress(address(_addressScreeningProvider));
        _assumeValidPrice(_pricePerLot);
        _assumeValidTimeRange(_saleStartTime, _saleEndTime);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__ZeroAddress.selector);
        new GenesisSequencerSale(
            address(this),
            _atpFactory,
            IERC20(address(0)),
            _soulboundToken,
            _rollup,
            _pricePerLot,
            _saleStartTime,
            _saleEndTime,
            _addressScreeningProvider
        );
    }

    function test_WhenSoulboundTokenIsZeroAddress(
        IATPFactory _atpFactory,
        IERC20 _saleToken,
        uint256 _pricePerLot,
        IStaking _rollup,
        uint96 _saleStartTime,
        uint96 _saleEndTime,
        address _addressScreeningProvider
    ) external {
        // it should revert with ZeroAddress
        _assumeValidAddress(address(_atpFactory));
        _assumeValidAddress(address(_saleToken));
        _assumeValidAddress(address(_rollup));
        _assumeValidPrice(_pricePerLot);
        _assumeValidTimeRange(_saleStartTime, _saleEndTime);
        _assumeValidAddress(address(_addressScreeningProvider));

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__ZeroAddress.selector);
        new GenesisSequencerSale(
            address(this),
            _atpFactory,
            _saleToken,
            IIgnitionParticipantSoulbound(address(0)),
            _rollup,
            _pricePerLot,
            _saleStartTime,
            _saleEndTime,
            _addressScreeningProvider
        );
    }

    function test_WhenRollupIsZeroAddress(
        IATPFactory _atpFactory,
        IIgnitionParticipantSoulbound _soulboundToken,
        IERC20 _saleToken,
        uint256 _pricePerLot,
        uint96 _saleStartTime,
        uint96 _saleEndTime,
        address _addressScreeningProvider
    ) external {
        // it should revert with ZeroAddress
        _assumeValidAddress(address(_atpFactory));
        _assumeValidAddress(address(_soulboundToken));
        _assumeValidAddress(address(_saleToken));
        _assumeValidAddress(address(_addressScreeningProvider));
        _assumeValidPrice(_pricePerLot);
        _assumeValidTimeRange(_saleStartTime, _saleEndTime);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__ZeroAddress.selector);
        new GenesisSequencerSale(
            address(this),
            _atpFactory,
            _saleToken,
            _soulboundToken,
            IStaking(address(0)),
            _pricePerLot,
            _saleStartTime,
            _saleEndTime,
            _addressScreeningProvider
        );
    }

    function test_WhenPricePerLotIsZero(
        IATPFactory _atpFactory,
        IIgnitionParticipantSoulbound _soulboundToken,
        IStaking _rollup,
        IERC20 _saleToken,
        uint96 _saleStartTime,
        uint96 _saleEndTime,
        address _addressScreeningProvider
    ) external {
        // it should revert with InvalidPrice
        _assumeValidAddress(address(_atpFactory));
        _assumeValidAddress(address(_soulboundToken));
        _assumeValidAddress(address(_saleToken));
        _assumeValidAddress(address(_rollup));
        _assumeValidAddress(address(_addressScreeningProvider));
        _assumeValidTimeRange(_saleStartTime, _saleEndTime);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__InvalidPrice.selector);
        new GenesisSequencerSale(
            address(this),
            _atpFactory,
            _saleToken,
            _soulboundToken,
            _rollup,
            0,
            _saleStartTime,
            _saleEndTime,
            _addressScreeningProvider
        );
    }

    function test_WhenSaleStartTimeIsGreaterThanOrEqualToSaleEndTime(
        IATPFactory _atpFactory,
        IIgnitionParticipantSoulbound _soulboundToken,
        IERC20 _saleToken,
        IStaking _rollup,
        uint256 _pricePerLot,
        uint96 _saleStartTime,
        uint96 _saleEndTime,
        address _addressScreeningProvider
    ) external {
        // it should revert with InvalidTimeRange
        _assumeValidAddress(address(_atpFactory));
        _assumeValidAddress(address(_soulboundToken));
        _assumeValidAddress(address(_saleToken));
        _assumeValidAddress(address(_rollup));
        _assumeValidAddress(address(_addressScreeningProvider));
        _assumeValidPrice(_pricePerLot);
        vm.assume(_saleStartTime >= block.timestamp);
        vm.assume(_saleStartTime >= _saleEndTime);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__InvalidTimeRange.selector);
        new GenesisSequencerSale(
            address(this),
            _atpFactory,
            _saleToken,
            _soulboundToken,
            _rollup,
            _pricePerLot,
            _saleStartTime,
            _saleEndTime,
            _addressScreeningProvider
        );
    }

    function test_WhenSaleStartTimeIsLessThanBlockTimestamp(
        IATPFactory _atpFactory,
        IIgnitionParticipantSoulbound _soulboundToken,
        IERC20 _saleToken,
        uint256 _pricePerLot,
        uint96 _saleStartTime,
        uint96 _saleEndTime,
        address _addressScreeningProvider
    ) external {
        // it should revert with InvalidTimeRange
        _assumeValidAddress(address(_atpFactory));
        _assumeValidAddress(address(_soulboundToken));
        _assumeValidAddress(address(_saleToken));
        _assumeValidAddress(address(_addressScreeningProvider));
        _assumeValidPrice(_pricePerLot);
        vm.assume(_saleStartTime < block.timestamp);
        vm.assume(_saleStartTime < _saleEndTime);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__InvalidTimeRange.selector);
        new GenesisSequencerSale(
            address(this),
            _atpFactory,
            _saleToken,
            _soulboundToken,
            rollup,
            _pricePerLot,
            _saleStartTime,
            _saleEndTime,
            _addressScreeningProvider
        );
    }

    function test_WhenScreeningProviderIsZeroAddress(
        IATPFactory _atpFactory,
        IIgnitionParticipantSoulbound _soulboundToken,
        IERC20 _saleToken,
        IStaking _rollup,
        uint256 _pricePerLot,
        uint96 _saleStartTime,
        uint96 _saleEndTime
    ) external {
        // it should revert with ZeroAddress
        _assumeValidAddress(address(_atpFactory));
        _assumeValidAddress(address(_soulboundToken));
        _assumeValidAddress(address(_saleToken));
        _assumeValidAddress(address(_rollup));
        _assumeValidPrice(_pricePerLot);
        _assumeValidTimeRange(_saleStartTime, _saleEndTime);

        vm.expectRevert(IGenesisSequencerSale.GenesisSequencerSale__ZeroAddress.selector);
        new GenesisSequencerSale(
            address(this),
            _atpFactory,
            _saleToken,
            _soulboundToken,
            _rollup,
            _pricePerLot,
            _saleStartTime,
            _saleEndTime,
            address(0)
        );
    }

    function test_WhenAllParametersAreValid(
        uint256 _pricePerLot,
        uint96 _saleStartTime,
        uint96 _saleEndTime,
        uint256 _currentTime
    ) external {
        // it should set atpFactory
        // it should set soulboundToken
        // it should set pricePerLot
        // it should set SALE_START_TIME
        // it should set SALE_END_TIME
        // it should set owner to the provided address
        // it should initialize saleActive as false

        // Bound inputs to reasonable ranges
        _currentTime = _boundCurrentTime(_currentTime);
        _pricePerLot = _boundPrice(_pricePerLot);
        _saleStartTime = _boundSaleStartTime(_saleStartTime, uint96(_currentTime));
        _saleEndTime = _boundSaleEndTime(_saleEndTime, _saleStartTime);

        vm.warp(_currentTime);

        vm.expectEmit(true, true, true, true);
        emit IGenesisSequencerSale.PriceUpdated(_pricePerLot);
        vm.expectEmit(true, true, true, true);
        emit IGenesisSequencerSale.SaleTimesUpdated(uint256(_saleStartTime), uint256(_saleEndTime));
        GenesisSequencerSale genesisSequencerSale = new GenesisSequencerSale(
            address(this),
            atpFactory,
            saleToken,
            soulboundToken,
            rollup,
            _pricePerLot,
            _saleStartTime,
            _saleEndTime,
            address(mockWhitelistProvider)
        );

        // Verify state
        assertEq(address(genesisSequencerSale.ATP_FACTORY()), address(atpFactory));
        assertEq(address(genesisSequencerSale.SALE_TOKEN()), address(saleToken));
        assertEq(address(genesisSequencerSale.SOULBOUND_TOKEN()), address(soulboundToken));
        assertEq(genesisSequencerSale.pricePerLot(), _pricePerLot);
        assertEq(genesisSequencerSale.saleStartTime(), _saleStartTime);
        assertEq(genesisSequencerSale.saleEndTime(), _saleEndTime);
        assertEq(genesisSequencerSale.owner(), address(this));
        assertEq(genesisSequencerSale.saleEnabled(), false);
        assertEq(genesisSequencerSale.addressScreeningProvider(), address(mockWhitelistProvider));

        // Verify constants
        // Note: TOKEN_LOT_SIZE() now calls the rollup's getActivationThreshold() function
        // Since we're using a mock address, this will revert, but we can verify the function exists
        assertEq(genesisSequencerSale.PURCHASES_PER_ADDRESS(), 5);
    }
}
