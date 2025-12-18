// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {Test} from "forge-std/Test.sol";
import {GenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {MockGSE} from "test/mocks/staking/MockGSE.sol";
import {MockRollup} from "test/mocks/staking/MockRollup.sol";
import {IATPFactory, ATPFactory, IRegistry} from "@atp/ATPFactory.sol";
import {StakerVersion} from "@atp/Registry.sol";
import {MockTrueWhitelistProvider, MockFalseWhitelistProvider} from "../../mocks/MockWhitelistProvider.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {IWhitelistProvider} from "src/soulbound/providers/IWhitelistProvider.sol";
import {IgnitionParticipantSoulbound} from "src/soulbound/IgnitionParticipantSoulbound.sol";
import {console, console2} from "forge-std/Test.sol";

import {MockTrueWhitelistProvider, MockFalseWhitelistProvider} from "../../mocks/MockWhitelistProvider.sol";
import {IWhitelistProvider} from "src/soulbound/providers/IWhitelistProvider.sol";

contract GenesisSequencerSaleBase is Test {
    // We are running with a super small tree right now for testing purposes
    uint256 public constant TREE_SIZE = 8;

    GenesisSequencerSale public genesisSequencerSale;

    MockERC20 public saleToken;
    MockRollup public rollup;
    MockGSE public gse;
    IATPFactory public atpFactory;
    IRegistry public atpRegistry;
    address public matpImplementation;
    address public latpImplementation;
    address public ncatpImplementation;

    uint256 public unlockCliffDuration = 1 days;
    uint256 public unlockLockDuration = 1 days;

    IWhitelistProvider public mockTrueWhitelistProvider;
    IWhitelistProvider public mockFalseWhitelistProvider;

    IgnitionParticipantSoulbound public soulboundToken;

    uint256 public pricePerLot = 5 ether;
    uint96 public SALE_START_TIME = uint96(block.timestamp);
    uint96 public SALE_END_TIME = uint96(block.timestamp + 1 days);

    bytes32[] public emptyMerkleProof = new bytes32[](0);

    address public FOUNDATION_ADDRESS = makeAddr("FOUNDATION_ADDRESS");
    address public REVOKE_BENEFICIARY = FOUNDATION_ADDRESS;
    address public rollupAddress;

    address public screeningProvider;

    uint256 public gridTileId = 1;

    function setUp() public virtual {
        saleToken = new MockERC20("Sale Token", "SALE");
        atpFactory = new ATPFactory(FOUNDATION_ADDRESS, saleToken, unlockCliffDuration, unlockLockDuration);

        gse = new MockGSE();
        rollup = new MockRollup(saleToken, gse);

        atpRegistry = atpFactory.getRegistry();
        latpImplementation = vm.computeCreateAddress(address(atpFactory), 2);
        matpImplementation = vm.computeCreateAddress(address(atpFactory), 3);
        ncatpImplementation = vm.computeCreateAddress(address(atpFactory), 4);

        mockTrueWhitelistProvider = new MockTrueWhitelistProvider();
        mockFalseWhitelistProvider = new MockFalseWhitelistProvider();

        address[] memory whitelistProviders = new address[](2);
        whitelistProviders[0] = address(mockTrueWhitelistProvider);
        whitelistProviders[1] = address(mockFalseWhitelistProvider);

        vm.prank(FOUNDATION_ADDRESS);
        soulboundToken = new IgnitionParticipantSoulbound(
            address(0), whitelistProviders, bytes32(0), bytes32(0), address(mockTrueWhitelistProvider), ""
        );

        screeningProvider = address(mockTrueWhitelistProvider);

        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale = new GenesisSequencerSale(
            FOUNDATION_ADDRESS,
            atpFactory,
            saleToken,
            soulboundToken,
            rollup,
            pricePerLot,
            SALE_START_TIME,
            SALE_END_TIME,
            screeningProvider
        );

        vm.prank(FOUNDATION_ADDRESS);
        soulboundToken.setTokenSaleAddress(address(genesisSequencerSale));

        vm.prank(FOUNDATION_ADDRESS);
        atpFactory.setMinter(address(genesisSequencerSale), true);

        // Label addresses
        vm.label(address(genesisSequencerSale), "Genesis Sequencer Sale");
        vm.label(address(atpFactory), "ATP Factory");
        vm.label(address(soulboundToken), "Whitelist Soulbound");
        vm.label(address(mockTrueWhitelistProvider), "Mock True Whitelist Provider");
        vm.label(address(mockFalseWhitelistProvider), "Mock False Whitelist Provider");
        vm.label(address(rollupAddress), "Rollup Address");
        vm.label(address(screeningProvider), "Screening Provider");
        vm.label(address(rollup), "Rollup");
    }

    function assumeAddress(address _address) public view {
        vm.assume(
            _address != address(0) && _address != address(this) && _address != address(genesisSequencerSale)
                && _address != address(atpFactory) && _address != address(soulboundToken)
                && _address != address(mockTrueWhitelistProvider) && _address != address(mockFalseWhitelistProvider)
                && _address != address(atpRegistry) && _address != address(vm) && _address != address(rollup)
                && _address != address(gse) && _address != address(saleToken)
                && _address != address(0x4e59b44847b379578588920cA78FbF26c0B4956C) // create2
                && _address != address(atpRegistry.getStakerImplementation(StakerVersion.wrap(0)))
                && _address != address(CONSOLE) && _address != address(screeningProvider)
                && _address != address(rollupAddress) && _address != address(matpImplementation)
                && _address != address(latpImplementation) && _address != address(ncatpImplementation)
        );
    }

    function boundTreeIndex(uint8 _treeIndex) public pure returns (uint8) {
        return uint8(bound(_treeIndex, 0, TREE_SIZE));
    }

    function initTrees() public {
        setGenesisSequencerMerkleRootFromFile();
        setContributorMerkleRootFromFile();
    }

    /**
     * BTT Modifiers
     */
    modifier givenSaleIsActive() {
        isSaleActive(true);
        hasSaleStarted(true);
        _;
    }

    function mintUserAlignedSoulboundToken(address _user, bytes32[] memory _merkleProof) public {
        vm.startPrank(_user);
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
            _user,
            _merkleProof,
            address(mockTrueWhitelistProvider),
            bytes(""),
            bytes(""),
            gridTileId++
        );
        vm.stopPrank();
    }

    function mintUserContributorSoulboundToken(address _user, bytes32[] memory _merkleProof) public {
        vm.startPrank(_user);
        soulboundToken.mint(
            IIgnitionParticipantSoulbound.TokenId.CONTRIBUTOR,
            _user,
            _merkleProof,
            address(mockTrueWhitelistProvider),
            bytes(""),
            bytes(""),
            gridTileId++
        );
        vm.stopPrank();
    }

    function isSaleActive(bool _isSaleActive) public {
        if (_isSaleActive) {
            vm.prank(FOUNDATION_ADDRESS);
            genesisSequencerSale.startSale();
        } else {
            vm.prank(FOUNDATION_ADDRESS);
            genesisSequencerSale.stopSale();
        }
    }

    function hasSaleStarted(bool _hasSaleStarted) public {
        if (_hasSaleStarted) {
            vm.warp(SALE_START_TIME + 1);
        } else {
            vm.warp(SALE_START_TIME - 1);
        }
    }

    function hasSaleEnded(bool _hasSaleEnded) public {
        if (_hasSaleEnded) {
            vm.warp(SALE_END_TIME + 1);
        } else {
            vm.warp(SALE_END_TIME - 1);
        }
    }

    function setAddressScreeningFails() public {
        vm.prank(FOUNDATION_ADDRESS);
        soulboundToken.setAddressScreeningProvider(address(mockFalseWhitelistProvider));
    }

    function setSaleAddressScreeningFails() public {
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.setAddressScreeningProvider(address(mockFalseWhitelistProvider));
    }

    function setSaleAddressScreeningPasses() public {
        vm.prank(FOUNDATION_ADDRESS);
        genesisSequencerSale.setAddressScreeningProvider(address(mockTrueWhitelistProvider));
    }

    function setAddressScreeningPasses() public {
        vm.prank(FOUNDATION_ADDRESS);
        soulboundToken.setAddressScreeningProvider(address(mockTrueWhitelistProvider));
    }

    function setGenesisSequencerMerkleRootFromFile() public {
        bytes32 _merkleRoot = vm.parseBytes32(vm.readFile("merkle-tree/test-utils/test-outputs/genesis_sequencer_root.txt"));
        vm.prank(FOUNDATION_ADDRESS);
        soulboundToken.setGenesisSequencerMerkleRoot(_merkleRoot);
    }

    function setContributorMerkleRootFromFile() public {
        bytes32 _merkleRoot = vm.parseBytes32(vm.readFile("merkle-tree/test-utils/test-outputs/contributor_root.txt"));
        vm.prank(FOUNDATION_ADDRESS);
        soulboundToken.setContributorMerkleRoot(_merkleRoot);
    }

    function setGenesisSequencerMerkleRoot(bytes32 _merkleRoot) public {
        vm.prank(FOUNDATION_ADDRESS);
        soulboundToken.setGenesisSequencerMerkleRoot(_merkleRoot);
    }

    function setContributorMerkleRoot(bytes32 _merkleRoot) public {
        vm.prank(FOUNDATION_ADDRESS);
        soulboundToken.setContributorMerkleRoot(_merkleRoot);
    }

    function fundTokenSale(uint256 _amount) public {
        vm.prank(FOUNDATION_ADDRESS);
        saleToken.mint(address(genesisSequencerSale), _amount);
    }

    function fundTokenSale() public {
        vm.prank(FOUNDATION_ADDRESS);
        saleToken.mint(address(genesisSequencerSale), 100_000_000_000 ether);
    }

    function fundATPFactory() public {
        vm.prank(FOUNDATION_ADDRESS);
        saleToken.mint(address(atpFactory), 100_000_000_000 ether);
    }

    // So that the base test contract can receive ETH
    receive() external payable {}
}
