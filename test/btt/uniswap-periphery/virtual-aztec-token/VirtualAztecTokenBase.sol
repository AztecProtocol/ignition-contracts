// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {VirtualAztecToken, IVirtualAztecToken} from "src/uniswap-periphery/VirtualAztecToken.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {IATPFactoryNonces} from "@atp/ATPFactoryNonces.sol";
import {IRegistry} from "@atp/Registry.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";

import {ATPFactoryNonces} from "@atp/ATPFactoryNonces.sol";

// uniswap
import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";

// Screening Providers
import {MockTrueWhitelistProvider, MockFalseWhitelistProvider} from "test/mocks/MockWhitelistProvider.sol";

contract MockAuction {
    uint64 public endBlock;

    constructor(uint64 _endBlock) {
        endBlock = _endBlock;
    }
}

contract VirtualAztecTokenBase is Test {
    VirtualAztecToken internal virtualAztecToken;
    MockERC20 internal underlyingToken;
    IATPFactoryNonces internal atpFactory;
    IContinuousClearingAuction internal auction;
    address internal strategy;
    address public foundationAddress = makeAddr("foundationAddress");

    MockTrueWhitelistProvider internal mockTrueWhitelistProvider;
    MockFalseWhitelistProvider internal mockFalseWhitelistProvider;

    string constant VIRTUAL_TOKEN_NAME = "Virtual-TOKEN";
    string constant VIRTUAL_TOKEN_SYMBOL = "VTOKEN";

    uint64 public END_BLOCK;

    IVirtualAztecToken.Signature internal emptySignature = IVirtualAztecToken.Signature({r: 0, s: 0, v: 0});

    constructor() {}

    function setUp() public virtual {
        END_BLOCK = uint64(block.number + 1000);

        mockTrueWhitelistProvider = new MockTrueWhitelistProvider();
        mockFalseWhitelistProvider = new MockFalseWhitelistProvider();

        underlyingToken = new MockERC20("Underlying Token", "UT");
        atpFactory = new ATPFactoryNonces(address(this), IERC20(address(underlyingToken)), 100, 100);

        // uniswap subsystem
        auction = IContinuousClearingAuction(address(new MockAuction(END_BLOCK)));
        strategy = makeAddr("strategy");

        virtualAztecToken = new VirtualAztecToken(
            VIRTUAL_TOKEN_NAME, VIRTUAL_TOKEN_SYMBOL, IERC20(address(underlyingToken)), atpFactory, foundationAddress
        );

        virtualAztecToken.setAuctionAddress(auction);
        virtualAztecToken.setStrategyAddress(strategy);
        virtualAztecToken.setScreeningProvider(address(mockTrueWhitelistProvider));

        assertEq(address(virtualAztecToken.ATP_FACTORY()), address(atpFactory));
        assertEq(address(virtualAztecToken.auctionAddress()), address(auction));
        assertEq(address(virtualAztecToken.strategyAddress()), strategy);
        assertEq(address(virtualAztecToken.UNDERLYING_TOKEN_ADDRESS()), address(underlyingToken));
        assertEq(virtualAztecToken.MIN_STAKE_AMOUNT(), 200_000 ether);
        assertEq(virtualAztecToken.owner(), address(this));
        assertEq(virtualAztecToken.name(), VIRTUAL_TOKEN_NAME);
        assertEq(virtualAztecToken.symbol(), VIRTUAL_TOKEN_SYMBOL);

        atpFactory.setMinter(address(virtualAztecToken), true);
    }

    modifier givenScreeningProviderSucceeds() {
        virtualAztecToken.setScreeningProvider(address(mockTrueWhitelistProvider));
        _;
    }

    modifier givenScreeningProviderFails() {
        virtualAztecToken.setScreeningProvider(address(mockFalseWhitelistProvider));
        _;
    }

    // Generate a valid signature for the given private key
    function helper__generateSignature(uint256 _privateKey, address _owner, address _beneficiary, uint256 _deadline)
        internal
        view
        returns (IVirtualAztecToken.Signature memory)
    {
        uint256 nonce = virtualAztecToken.nonces(_owner);
        bytes32 digest = virtualAztecToken.getSetAtpBeneficiaryWithSignatureDigest(_owner, _beneficiary, _deadline, nonce);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, digest);
        return IVirtualAztecToken.Signature({r: r, s: s, v: v});
    }

    function __helper__mint(address _to, uint256 _amount) public {
        underlyingToken.mint(address(this), _amount);
        underlyingToken.approve(address(virtualAztecToken), _amount);

        virtualAztecToken.mint(_to, _amount);
    }

    function mintVirtualAztecTokenIntoAuction(uint256 _amount) public {
        __helper__mint(address(auction), _amount);
    }

    function mintVirtualAztecTokenIntoStrategy(uint256 _amount) public {
        __helper__mint(address(strategy), _amount);
    }
}
