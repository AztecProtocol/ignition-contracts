// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// Contracts - Soulbound
import {IgnitionParticipantSoulbound} from "src/soulbound/IgnitionParticipantSoulbound.sol";

// Contracts - Sale
import {GenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";

// Contracts - Providers
import {IWhitelistProvider} from "src/soulbound/providers/IWhitelistProvider.sol";
import {ZKPassportProvider} from "src/soulbound/providers/ZKPassportProvider.sol";
import {AttestationProvider} from "src/soulbound/providers/AttestationProvider.sol";
import {PredicateProvider} from "src/soulbound/providers/PredicateProvider.sol";
import {PredicateMessage} from "@predicate/interfaces/IPredicateClient.sol";
import {IPredicateProvider} from "src/soulbound/providers/PredicateProvider.sol";

// Contracts - ATP
import {ATPFactory, Registry, IRegistry} from "@atp/ATPFactory.sol";
import {ATPNonWithdrawableStaker} from "src/staking/ATPNonWithdrawableStaker.sol";

// Contracts - ATP Staking
import {ATPNonWithdrawableStaker} from "src/staking/ATPNonWithdrawableStaker.sol";
import {ATPWithdrawableStaker} from "src/staking/ATPWithdrawableStaker.sol";

// Contracts - Staking Registry
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {StakingRegistry} from "src/staking-registry/StakingRegistry.sol";

// External contracts - Splits
import {SplitsWarehouse} from "@splits/SplitsWarehouse.sol";
import {PullSplitFactory} from "@splits/splitters/pull/PullSplitFactory.sol";

// Mocks
import {MockERC20} from "test/mocks/MockERC20.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {MockRollup} from "test/mocks/staking/MockRollup.sol";
import {MockRegistry} from "test/mocks/staking/MockRegistry.sol";
import {MockGovernance} from "test/mocks/staking/MockGovernance.sol";
import {MockGSE} from "test/mocks/staking/MockGSE.sol";
import {MockPredicateManager} from "test/mocks/soulbound/MockPredicateManager.sol";

// Test utils
import {TestMerkleTreeGetters} from "test/merkle-tree/merkle_tree_getters.sol";
import {ZKPassportBase} from "test/btt/soulbound/providers/zkpassport/ZKPassportBase.sol";

// Libraries
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

abstract contract IntegrationTestBase is TestMerkleTreeGetters, ZKPassportBase {
    IERC20 public stakingAsset;
    MockRollup public rollup;
    MockRegistry public rollupRegistry;
    MockGSE public gse;
    MockGovernance public governance;

    IRegistry public atpRegistry;
    ATPFactory public atpFactory;
    IgnitionParticipantSoulbound public soulboundToken;
    GenesisSequencerSale public genesisSequencerSale;

    IWhitelistProvider public zkPassportWhitelistProvider;
    IWhitelistProvider public attestationWhitelistProvider;
    IWhitelistProvider public predicateWhitelistProvider;
    IWhitelistProvider public predicateSaleProvider;

    IStakingRegistry public stakingRegistry;
    ATPNonWithdrawableStaker public atpNonWithdrawableStaker;
    ATPWithdrawableStaker public atpWithdrawableStaker;

    SplitsWarehouse public splitsWarehouse;
    PullSplitFactory public pullSplitFactory;

    // TODO: not used in this flow - add predicate test case
    uint256 internal attestationSigningKey = 0x0000000000000000000000000000000000000000000000000000000000000042;
    address internal attestationSigner = vm.addr(attestationSigningKey);

    // Sale parameters - sale is active for 1 week
    uint256 public pricePerLot = 5 ether;
    uint96 public SALE_START_TIME;
    uint96 public SALE_END_TIME;

    // ATP factory parameters
    uint256 public unlockLockDuration = 365 days;
    uint256 public unlockCliffDuration = 180 days;

    // Who we have done the zkpassport bind proof for
    address participant = address(0x04Fb06E8BF44eC60b6A99D2F98551172b2F2dED8);

    // Aztec Foundation addresses
    address public FOUNDATION_ADDRESS = makeAddr("FOUNDATION_ADDRESS");
    address public REVOKE_BENEFICIARY = FOUNDATION_ADDRESS;

    function setUp() public virtual override(ZKPassportBase) {
        super.setUp();

        // Set test start time
        // Set the timestamp to 2025-07-16 20:26:48 UTC
        vm.warp(PROOF_GENERATION_TIMESTAMP);
        SALE_START_TIME = uint96(block.timestamp + 1 days);
        SALE_END_TIME = uint96(block.timestamp + 8 days);

        ///////////////////////////////////////////////////////
        /// Set Mocks - Staking Asset, Rollup, and Rollup Registry
        ///////////////////////////////////////////////////////
        stakingAsset = new MockERC20("Staking Asset", "SA");
        gse = new MockGSE();
        rollup = new MockRollup(stakingAsset, gse);
        gse.addRollup(address(rollup));

        governance = new MockGovernance(address(stakingAsset));
        rollupRegistry = new MockRegistry(address(governance));
        rollupRegistry.addRollup(0, address(rollup));

        ///////////////////////////////////////////////////////
        /// Set up ATP Factory
        ///////////////////////////////////////////////////////
        atpFactory = new ATPFactory(FOUNDATION_ADDRESS, stakingAsset, unlockCliffDuration, unlockLockDuration);
        atpRegistry = atpFactory.getRegistry();

        ///////////////////////////////////////////////////////
        /// Set up Revoker on ATP Factory
        ///////////////////////////////////////////////////////
        // Set revoker to the foundation address
        vm.prank(FOUNDATION_ADDRESS);
        atpRegistry.setRevoker(FOUNDATION_ADDRESS);

        // Set revoker operator to the foundation address
        vm.prank(FOUNDATION_ADDRESS);
        atpRegistry.setRevokerOperator(FOUNDATION_ADDRESS);

        ///////////////////////////////////////////////////////
        /// Set up Soulbound Token Providers
        ///////////////////////////////////////////////////////

        zkPassportWhitelistProvider =
            new ZKPassportProvider(address(soulboundToken), address(zkPassportVerifier), CORRECT_DOMAIN, CORRECT_SCOPE);
        attestationWhitelistProvider = new AttestationProvider(address(soulboundToken), attestationSigner);
        MockPredicateManager predicateManager = new MockPredicateManager();
        predicateWhitelistProvider = new PredicateProvider(address(this), address(predicateManager), "test-soulbound");
        predicateSaleProvider = new PredicateProvider(address(this), address(predicateManager), "test-sale");

        predicateManager.setPolicyResponse("test-soulbound", true);
        predicateManager.setPolicyResponse("test-sale", true);

        address[] memory whitelistProviders = new address[](2);
        whitelistProviders[0] = address(zkPassportWhitelistProvider);
        whitelistProviders[1] = address(attestationWhitelistProvider);

        // Create a merkle tree for just the participant's address
        bytes32 genesisSequencerMerkleRoot = makeMerkleTreeAndGetProof(participant);

        soulboundToken = new IgnitionParticipantSoulbound(
            address(0),
            whitelistProviders,
            genesisSequencerMerkleRoot,
            bytes32(0),
            address(predicateWhitelistProvider),
            ""
        );
        ZKPassportProvider(address(zkPassportWhitelistProvider)).setConsumer(address(soulboundToken));
        AttestationProvider(address(attestationWhitelistProvider)).setConsumer(address(soulboundToken));
        PredicateProvider(address(predicateWhitelistProvider)).setConsumer(address(soulboundToken));

        ///////////////////////////////////////////////////////
        /// Set up Aligned Sale
        ///////////////////////////////////////////////////////
        genesisSequencerSale = new GenesisSequencerSale(
            address(this),
            atpFactory,
            stakingAsset,
            soulboundToken,
            rollup,
            pricePerLot,
            SALE_START_TIME,
            SALE_END_TIME,
            address(predicateSaleProvider)
        );
        soulboundToken.setTokenSaleAddress(address(genesisSequencerSale));
        PredicateProvider(address(predicateSaleProvider)).setConsumer(address(genesisSequencerSale));

        ///////////////////////////////////////////////////////
        /// Set up Staking Contracts + Staking Registry
        ///////////////////////////////////////////////////////
        // Splits contracts
        splitsWarehouse = new SplitsWarehouse("eth", "eth");
        pullSplitFactory = new PullSplitFactory(address(splitsWarehouse));

        // ATP Staking Registry
        stakingRegistry = new StakingRegistry(stakingAsset, address(pullSplitFactory), rollupRegistry);

        // Staking contracts
        atpNonWithdrawableStaker = new ATPNonWithdrawableStaker(stakingAsset, rollupRegistry, stakingRegistry);
        atpWithdrawableStaker = new ATPWithdrawableStaker(stakingAsset, rollupRegistry, stakingRegistry);

        ///////////////////////////////////////////////////////
        /// Mint tokens to the ATP Factory
        ///////////////////////////////////////////////////////
        // Set the aligned sale contract to be a minter of the api
        vm.prank(FOUNDATION_ADDRESS);
        atpFactory.setMinter(address(genesisSequencerSale), true);

        // Fund the atp factory with some aztec tokens
        uint256 ONE_HUNDRED_TOKEN_LOT_SIZE = 100 * genesisSequencerSale.TOKEN_LOT_SIZE();
        MockERC20(address(stakingAsset)).mint(address(genesisSequencerSale), ONE_HUNDRED_TOKEN_LOT_SIZE);
    }

    function makeSalePredicateAttestation() internal returns (PredicateMessage memory) {
        return makePredicateAttestation("test-sale");
    }

    function makeSoulboundPredicateAttestation() internal returns (PredicateMessage memory) {
        return makePredicateAttestation("test-soulbound");
    }

    function makePredicateAttestation(string memory _taskId) internal returns (PredicateMessage memory) {
        uint256 expireByTime = block.timestamp + 1 hours;
        address[] memory signerAddresses = new address[](1);
        signerAddresses[0] = makeAddr("predicateSigner");
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = bytes("");

        PredicateMessage memory message = PredicateMessage({
            taskId: _taskId, expireByTime: expireByTime, signerAddresses: signerAddresses, signatures: signatures
        });

        return message;
    }

    function makeKeyStore(string memory _name) internal returns (IStakingRegistry.KeyStore memory) {
        return IStakingRegistry.KeyStore({
            attester: makeAddr(_name),
            publicKeyG1: BN254Lib.G1Point({x: 0, y: 0}),
            publicKeyG2: BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
            proofOfPossession: BN254Lib.G1Point({x: 0, y: 0})
        });
    }
}
