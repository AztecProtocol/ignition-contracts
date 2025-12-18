// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

// Atp contracts
import {ATPFactory} from "@atp/ATPFactory.sol";
import {Registry as ATPRegistry, StakerVersion} from "@atp/Registry.sol";

// Core contracts
import {IgnitionParticipantSoulbound} from "src/soulbound/IgnitionParticipantSoulbound.sol";
import {GenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";

// Providers for the token sale
import {ZKPassportProvider} from "src/soulbound/providers/ZKPassportProvider.sol";
import {PredicateProvider} from "src/soulbound/providers/PredicateProvider.sol";
import {IWhitelistProvider} from "src/soulbound/providers/IWhitelistProvider.sol";
// import {AttestationProvider} from "src/soulbound/providers/AttestationProvider.sol";

// Mocks
import {MockPredicateProvider} from "test/mocks/MockPredicateProvider.sol";

// Splits contracts
import {SplitsWarehouse} from "@splits/SplitsWarehouse.sol";
import {PullSplitFactory} from "@splits/splitters/pull/PullSplitFactory.sol";

// Staking contracts
import {ATPWithdrawableAndClaimableStaker} from "src/staking/ATPWithdrawableAndClaimableStaker.sol";
import {StakingRegistry, IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";

// TODO: this is a mock interface - not the real one
import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";
import {IStaking} from "src/staking/rollup-system-interfaces/IStaking.sol";

import {IERC20Mintable} from "@teegeeee/token/IERC20Mintable.sol";

// Utilities
import {MerkleTreeGetters} from "test/merkle-tree/merkle_tree_getters.sol";
import {Ownable} from "@oz/access/Ownable.sol";

import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

import {FoundationWallets} from "../CollectiveDeploy.s.sol";

import {
    GenesisSaleConfiguration,
    ZkPassportConfiguration,
    PredicateConfiguration,
    AtpConfiguration,
    SaleConfiguration
} from "./GenesisSaleConfiguration.sol";
import {ConfigurationVariant, ChainEnvironment} from "../SharedConfig.sol";

contract DeployGenesisSaleContracts is MerkleTreeGetters, Script {
    struct DeployedContracts {
        // From previous steps
        address zkPassportVerifierAddress;
        address stakingAssetAddress;
        address rollupAddress;
        address rollupRegistryAddress;
        // New in this step
        address atpFactory;
        address atpRegistry;
        address zkPassportProvider;
        address predicateSanctionsProvider;
        address predicateSanctionsProviderSale;
        address predicateKYCProvider;
        address soulboundToken;
        uint256 soulboundTokenDeploymentBlock;
        address genesisSequencerSale;
        address splitsWarehouse;
        address pullSplitFactory;
        address stakingRegistry;
        address atpWithdrawableAndClaimableStaker;
        // Other values
        uint256 genesisSequencerSupply;
    }

    GenesisSaleConfiguration internal CONFIGURATION;
    ChainEnvironment internal CHAIN_ENVIRONMENT;
    FoundationWallets internal WALLETS;
    DeployedContracts internal deployedContracts;

    function getDeployedContracts() public view returns (DeployedContracts memory) {
        return deployedContracts;
    }

    function run() external {
        _deploySplits();

        _deployStakingRegistry();

        _deploySoulBoundTokenAndProviders();

        _deployATPFactory();

        _deployGenesisSale();

        _transferOwnerships();

        _assertConfiguration();
    }

    function setEnv(
        ConfigurationVariant _configurationVariant,
        ChainEnvironment _chainEnvironment,
        FoundationWallets memory _foundationWallets,
        address _stakingAssetAddress,
        address _rollupAddress,
        address _rollupRegistryAddress
    ) public {
        CONFIGURATION = new GenesisSaleConfiguration(_configurationVariant);
        CHAIN_ENVIRONMENT = _chainEnvironment;
        WALLETS = _foundationWallets;
        deployedContracts.stakingAssetAddress = _stakingAssetAddress;
        deployedContracts.rollupAddress = _rollupAddress;
        deployedContracts.rollupRegistryAddress = _rollupRegistryAddress;
    }

    function _deploySplits() internal {
        // Deploy the splits warehouses if anvil, otherwise use already deployed ones

        if (block.chainid == 31337) {
            vm.broadcast(WALLETS.deployer);
            SplitsWarehouse splitsWarehouse = new SplitsWarehouse("eth", "eth");
            vm.broadcast(WALLETS.deployer);
            PullSplitFactory pullSplitFactory = new PullSplitFactory(address(splitsWarehouse));
            deployedContracts.splitsWarehouse = address(splitsWarehouse);
            deployedContracts.pullSplitFactory = address(pullSplitFactory);
        } else {
            deployedContracts.pullSplitFactory = CONFIGURATION.getPullSplitFactoryAddress();
        }
    }

    function _deployStakingRegistry() internal {
        // Deploys the staking registry and staking contracts
        // Registers a staking provider and adds a key for it

        vm.broadcast(WALLETS.deployer);
        StakingRegistry stakingRegistry = new StakingRegistry(
            IERC20(deployedContracts.stakingAssetAddress),
            address(deployedContracts.pullSplitFactory),
            IRegistry(deployedContracts.rollupRegistryAddress)
        );
        deployedContracts.stakingRegistry = address(stakingRegistry);

        // Note: don't run below this point if on a mainnet. No need for the key to be registered there.
        // Register staking provider
        if (block.chainid == 1 && CHAIN_ENVIRONMENT == ChainEnvironment.REAL_MAINNET) {
            return;
        }

        vm.broadcast(WALLETS.deployer);
        IStakingRegistry(deployedContracts.stakingRegistry).registerProvider(WALLETS.deployer, 1000, WALLETS.deployer);

        // We load from the `attester_inputs.json`
        emit log("Fetching validator keys from attester_inputs.json and adding to staking registry");
        IStakingRegistry.KeyStore[] memory providerKeys = _loadValidatorKeys(10);

        // The first provider we registered has id = 1. Use it here as param
        vm.broadcast(WALLETS.deployer);
        IStakingRegistry(deployedContracts.stakingRegistry).addKeysToProvider(1, providerKeys);
    }

    // NOTE: FOR THE LOVE OF GOD. DO NOT TOUCH THIS STRUCT. It is alphabetically ordered.
    struct RegistrationData {
        address attester_address;
        bytes32 attester_private_key;
        BN254Lib.G1Point proofOfPossession;
        BN254Lib.G1Point publicKeyInG1;
        BN254Lib.G2Point publicKeyInG2;
    }

    function _loadValidatorKeys(uint256 _count) internal returns (IStakingRegistry.KeyStore[] memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/shell-scripts/attester_inputs.json");

        IStakingRegistry.KeyStore[] memory keys = new IStakingRegistry.KeyStore[](_count);

        for (uint256 i = 0; i < _count; i++) {
            // Build the jq command to extract the n'th element from the JSON array
            string[] memory inputs = new string[](4);
            inputs[0] = "jq";
            inputs[1] = "-r";
            inputs[2] = string.concat(".[", vm.toString(i), "]");
            inputs[3] = path;

            // Execute jq via FFI to get the n'th element as JSON string
            bytes memory result = vm.ffi(inputs);
            string memory elementJson = string(result);

            // Parse the individual element JSON
            bytes memory jsonBytes = vm.parseJson(elementJson);
            RegistrationData memory registration = abi.decode(jsonBytes, (RegistrationData));

            // Populate the KeyStore struct
            keys[i] = IStakingRegistry.KeyStore({
                attester: registration.attester_address,
                publicKeyG1: registration.publicKeyInG1,
                publicKeyG2: registration.publicKeyInG2,
                proofOfPossession: registration.proofOfPossession
            });
        }

        return keys;
    }

    function _deploySoulBoundTokenAndProviders() internal {
        // Deploys the zk passport provider and predicate manager (currently mock)
        // Deploys the soulbound token and add it as consumer of providers

        ZkPassportConfiguration memory zkPassportConfiguration = CONFIGURATION.getZkPassportConfiguration();
        console2.log("Zk passport verifier address", zkPassportConfiguration.verifierAddress);
        deployedContracts.zkPassportVerifierAddress = zkPassportConfiguration.verifierAddress;

        vm.broadcast(WALLETS.deployer);
        ZKPassportProvider zkPassportProvider = new ZKPassportProvider(
            address(0x00),
            zkPassportConfiguration.verifierAddress,
            zkPassportConfiguration.domain,
            zkPassportConfiguration.scope
        );
        deployedContracts.zkPassportProvider = address(zkPassportProvider);

        // TODO: update this to use a predicate manager
        if (block.chainid == 31337) {
            PredicateConfiguration memory predicateConfiguration = CONFIGURATION.getPredicateConfiguration();
            vm.broadcast(WALLETS.deployer);
            IWhitelistProvider mockPredicateSanctionsProvider = new MockPredicateProvider(
                WALLETS.deployer, predicateConfiguration.managerAddress, predicateConfiguration.addressScreeningPolicyId
            );
            deployedContracts.predicateSanctionsProvider = address(mockPredicateSanctionsProvider);

            vm.broadcast(WALLETS.deployer);
            IWhitelistProvider mockPredicateKYCProvider = new MockPredicateProvider(
                WALLETS.deployer, predicateConfiguration.managerAddress, predicateConfiguration.kycPolicyId
            );
            deployedContracts.predicateKYCProvider = address(mockPredicateKYCProvider);
        } else if (CHAIN_ENVIRONMENT == ChainEnvironment.FORKED_MAINNET) {
            deployedContracts.predicateSanctionsProvider = address(0x730a010735492440ed161D9aFB4f95A07a357aea);
            deployedContracts.predicateKYCProvider = address(0x5Bbb0d9CbED5d39e01d9C5BE2a68B761DCcE8809);
        } else {
            PredicateConfiguration memory predicateConfiguration = CONFIGURATION.getPredicateConfiguration();

            vm.broadcast(WALLETS.deployer);
            PredicateProvider predicateSanctionsProvider = new PredicateProvider(
                WALLETS.deployer, predicateConfiguration.managerAddress, predicateConfiguration.addressScreeningPolicyId
            );
            deployedContracts.predicateSanctionsProvider = address(predicateSanctionsProvider);

            vm.broadcast(WALLETS.deployer);
            PredicateProvider predicateKYCProvider = new PredicateProvider(
                WALLETS.deployer, predicateConfiguration.managerAddress, predicateConfiguration.kycPolicyId
            );
            deployedContracts.predicateKYCProvider = address(predicateKYCProvider);
        }

        _deploySoulBoundToken();
    }

    function _deploySoulBoundToken() internal {
        {
            // Get the merkle roots for the genesis sequencer - requires yarn process-merkle-tree to be run beforehand
            bytes32 genesisSequencerMerkleRoot = getRoot(MerkleTreeType.GenesisSequencer);
            bytes32 contributorMerkleRoot = getRoot(MerkleTreeType.Contributor);

            address[] memory whitelistProviders = new address[](2);
            whitelistProviders[0] = address(deployedContracts.zkPassportProvider);
            whitelistProviders[1] = address(deployedContracts.predicateKYCProvider);

            vm.broadcast(WALLETS.deployer);
            IgnitionParticipantSoulbound soulboundToken = new IgnitionParticipantSoulbound(
                address(0),
                whitelistProviders,
                genesisSequencerMerkleRoot,
                contributorMerkleRoot,
                address(deployedContracts.predicateSanctionsProvider),
                "" // TODO: NFT Metadata
            );
            deployedContracts.soulboundToken = address(soulboundToken);
            deployedContracts.soulboundTokenDeploymentBlock = block.number;
        }

        vm.broadcast(WALLETS.deployer);
        ZKPassportProvider(address(deployedContracts.zkPassportProvider))
            .setConsumer(address(deployedContracts.soulboundToken));

        if (CHAIN_ENVIRONMENT == ChainEnvironment.FORKED_MAINNET) {
            vm.broadcast(0xE9BDCB32279186b8CaAD1A7Cc6E1044e71359F49);
            PredicateProvider(address(deployedContracts.predicateKYCProvider)).transferOwnership(WALLETS.deployer);
        }
        vm.broadcast(WALLETS.deployer);
        PredicateProvider(address(deployedContracts.predicateKYCProvider))
            .setConsumer(address(deployedContracts.soulboundToken));

        if (CHAIN_ENVIRONMENT == ChainEnvironment.FORKED_MAINNET) {
            vm.broadcast(0xE9BDCB32279186b8CaAD1A7Cc6E1044e71359F49);
            PredicateProvider(address(deployedContracts.predicateSanctionsProvider)).transferOwnership(WALLETS.deployer);
        }
        vm.broadcast(WALLETS.deployer);
        PredicateProvider(address(deployedContracts.predicateSanctionsProvider))
            .setConsumer(address(deployedContracts.soulboundToken));
    }

    function _deployATPFactory() internal {
        AtpConfiguration memory atpConfiguration = CONFIGURATION.getAtpConfiguration();

        console2.log("sale unlock duration lock", atpConfiguration.unlockLockDuration);
        console2.log("sale cliff duration      ", atpConfiguration.unlockCliffDuration);

        vm.broadcast(WALLETS.deployer);
        ATPFactory atpFactory = new ATPFactory(
            WALLETS.deployer,
            IERC20(deployedContracts.stakingAssetAddress),
            atpConfiguration.unlockCliffDuration,
            atpConfiguration.unlockLockDuration
        );
        deployedContracts.atpFactory = address(atpFactory);

        // Get the ATP REGISTRY
        ATPRegistry atpRegistry = ATPRegistry(address(atpFactory.getRegistry()));
        deployedContracts.atpRegistry = address(atpRegistry);

        // Update executeAllowedAt variable in order to allow execution of staking actions (default value allows approvals since Jan 2027)
        emit log("Setting execute allowed at");
        vm.broadcast(WALLETS.deployer);
        ATPRegistry(deployedContracts.atpRegistry).setExecuteAllowedAt(atpConfiguration.executionAllowedAt);

        {
            vm.broadcast(WALLETS.deployer);
            deployedContracts.atpWithdrawableAndClaimableStaker = address(
                new ATPWithdrawableAndClaimableStaker(
                    IERC20(deployedContracts.stakingAssetAddress),
                    IRegistry(deployedContracts.rollupRegistryAddress),
                    StakingRegistry(deployedContracts.stakingRegistry),
                    atpConfiguration.ncatpWithdrawalTimestamp
                )
            );
        }

        // Register Staker contract implementation that allow staking and withdrawals and claiming
        vm.broadcast(WALLETS.deployer);
        ATPRegistry(deployedContracts.atpRegistry)
            .registerStakerImplementation(deployedContracts.atpWithdrawableAndClaimableStaker);

        console2.log("ATP factory address", deployedContracts.atpFactory);
        console2.log("ATP registry address", deployedContracts.atpRegistry);
    }

    function _deployGenesisSale() internal {
        if (block.chainid == 31337) {
            PredicateConfiguration memory predicateConfiguration = CONFIGURATION.getPredicateConfiguration();
            vm.broadcast(WALLETS.deployer);
            IWhitelistProvider mockPredicateSanctionsProviderSale = new MockPredicateProvider(
                WALLETS.deployer, predicateConfiguration.managerAddress, predicateConfiguration.addressScreeningPolicyId
            );
            deployedContracts.predicateSanctionsProviderSale = address(mockPredicateSanctionsProviderSale);
        } else if (CHAIN_ENVIRONMENT == ChainEnvironment.FORKED_MAINNET) {
            deployedContracts.predicateSanctionsProviderSale = address(0x00E477F7C6a9f73C88e28690bCDdb4cAEAd71aCD);
        } else {
            PredicateConfiguration memory predicateConfiguration = CONFIGURATION.getPredicateConfiguration();
            vm.broadcast(WALLETS.deployer);
            PredicateProvider predicateSanctionsProviderSale = new PredicateProvider(
                WALLETS.deployer, predicateConfiguration.managerAddress, predicateConfiguration.addressScreeningPolicyId
            );
            deployedContracts.predicateSanctionsProviderSale = address(predicateSanctionsProviderSale);
        }

        SaleConfiguration memory saleConfiguration = CONFIGURATION.getSaleConfiguration();

        emit log_named_uint("Sale start time", saleConfiguration.saleStartTime);
        emit log_named_uint("Sale end time  ", saleConfiguration.saleEndTime);

        vm.broadcast(WALLETS.deployer);
        GenesisSequencerSale genesisSequencerSale = new GenesisSequencerSale(
            WALLETS.deployer,
            ATPFactory(deployedContracts.atpFactory),
            IERC20(deployedContracts.stakingAssetAddress),
            IgnitionParticipantSoulbound(deployedContracts.soulboundToken),
            IStaking(deployedContracts.rollupAddress),
            saleConfiguration.pricePerLot,
            saleConfiguration.saleStartTime,
            saleConfiguration.saleEndTime,
            address(deployedContracts.predicateSanctionsProviderSale)
        );
        deployedContracts.genesisSequencerSale = address(genesisSequencerSale);

        // Update the soulbound token to point to the sale contract as the token sale address
        vm.broadcast(WALLETS.deployer);
        IgnitionParticipantSoulbound(deployedContracts.soulboundToken)
            .setTokenSaleAddress(address(genesisSequencerSale));

        if (CHAIN_ENVIRONMENT == ChainEnvironment.FORKED_MAINNET) {
            vm.broadcast(0xE9BDCB32279186b8CaAD1A7Cc6E1044e71359F49);
            PredicateProvider(address(deployedContracts.predicateSanctionsProviderSale))
                .transferOwnership(WALLETS.deployer);
        }
        vm.broadcast(WALLETS.deployer);
        PredicateProvider(address(deployedContracts.predicateSanctionsProviderSale))
            .setConsumer(address(genesisSequencerSale));

        // Set the genesis sequencer sale contract to be a minter of the atp factory
        vm.broadcast(WALLETS.deployer);
        ATPFactory(deployedContracts.atpFactory).setMinter(address(deployedContracts.genesisSequencerSale), true);

        deployedContracts.genesisSequencerSupply = saleConfiguration.supply;

        // Start the sale
        vm.broadcast(WALLETS.deployer);
        GenesisSequencerSale(payable(deployedContracts.genesisSequencerSale)).startSale();

        vm.broadcast(WALLETS.deployer);
        GenesisSequencerSale(payable(deployedContracts.genesisSequencerSale))
            .transferOwnership(WALLETS.genesisSaleOwner);
    }

    function _transferOwnerships() internal {
        vm.startBroadcast(WALLETS.deployer);
        Ownable(deployedContracts.atpFactory).transferOwnership(WALLETS.lowValueOwner);
        Ownable(deployedContracts.zkPassportProvider).transferOwnership(WALLETS.lowValueOwner);
        Ownable(deployedContracts.predicateSanctionsProvider).transferOwnership(WALLETS.lowValueOwner);
        Ownable(deployedContracts.predicateKYCProvider).transferOwnership(WALLETS.lowValueOwner);
        Ownable(deployedContracts.predicateSanctionsProviderSale).transferOwnership(WALLETS.lowValueOwner);
        Ownable(deployedContracts.soulboundToken).transferOwnership(WALLETS.lowValueOwner);

        Ownable(deployedContracts.atpRegistry).renounceOwnership();
        vm.stopBroadcast();
    }

    function _assertConfiguration() internal {
        // assertNotEq(block.chainid, 1, "Don't use this on mainnet!");

        // Asserting that configurations of deployed contracts in here are matching what I saw in Notion
        // Going extremely direct here as as it makes it simpler for anyone to validate, and just simple
        assertLe(
            ATPRegistry(deployedContracts.atpRegistry).getExecuteAllowedAt(),
            block.timestamp,
            "Execute allowed at is not less than or equal to block timestamp"
        );

        _assertSaleConfiguration();
        _assertAtpFactoryConfiguration();
        _assertAtpRegistryConfiguration();
        _assertSoulBoundTokenConfiguration();
        _assertPredicateSanctionsProviderConfiguration();
        _assertPredicateSanctionsProviderSaleConfiguration();
        _assertPredicateKYCProviderConfiguration();
        _assertZkPassportProviderConfiguration();
    }

    function _assertSaleConfiguration() internal {
        SaleConfiguration memory saleConfiguration = CONFIGURATION.getSaleConfiguration();

        GenesisSequencerSale gss = GenesisSequencerSale(payable(deployedContracts.genesisSequencerSale));

        assertEq(gss.pricePerLot(), saleConfiguration.pricePerLot);
        assertEq(gss.saleEnabled(), true);
        assertEq(gss.saleStartTime(), saleConfiguration.saleStartTime);
        assertEq(gss.saleEndTime(), saleConfiguration.saleEndTime);

        assertEq(gss.addressScreeningProvider(), address(deployedContracts.predicateSanctionsProviderSale));
        assertEq(address(gss.SOULBOUND_TOKEN()), deployedContracts.soulboundToken);
        assertEq(address(gss.ATP_FACTORY()), deployedContracts.atpFactory);

        assertEq(gss.owner(), WALLETS.genesisSaleOwner);
    }

    function _assertAtpFactoryConfiguration() internal {
        AtpConfiguration memory atpConfiguration = CONFIGURATION.getAtpConfiguration();
        ATPFactory atpFactory = ATPFactory(deployedContracts.atpFactory);

        assertEq(atpFactory.minter(deployedContracts.genesisSequencerSale), true);

        assertEq(atpFactory.owner(), WALLETS.deployer);
        assertEq(atpFactory.pendingOwner(), WALLETS.lowValueOwner);
    }

    function _assertAtpRegistryConfiguration() internal {
        AtpConfiguration memory atpConfiguration = CONFIGURATION.getAtpConfiguration();
        ATPRegistry atpRegistry = ATPRegistry(address(ATPFactory(deployedContracts.atpFactory).getRegistry()));

        assertEq(atpRegistry.getGlobalLockParams().cliffDuration, atpConfiguration.unlockCliffDuration);
        assertEq(atpRegistry.getGlobalLockParams().lockDuration, atpConfiguration.unlockLockDuration);
        assertEq(atpRegistry.getExecuteAllowedAt(), atpConfiguration.executionAllowedAt);
        assertEq(StakerVersion.unwrap(atpRegistry.getNextStakerVersion()), 2);
        assertEq(
            atpRegistry.getStakerImplementation(StakerVersion.wrap(1)),
            address(deployedContracts.atpWithdrawableAndClaimableStaker)
        );

        assertEq(atpRegistry.owner(), address(0));
        assertEq(atpRegistry.pendingOwner(), address(0));
    }

    function _assertSoulBoundTokenConfiguration() internal {
        IgnitionParticipantSoulbound soulboundToken = IgnitionParticipantSoulbound(deployedContracts.soulboundToken);

        assertEq(soulboundToken.tokenSaleAddress(), address(deployedContracts.genesisSequencerSale));
        assertEq(soulboundToken.addressScreeningProvider(), address(deployedContracts.predicateSanctionsProvider));
        assertEq(soulboundToken.identityProviders(address(deployedContracts.zkPassportProvider)), true);
        assertEq(soulboundToken.identityProviders(address(deployedContracts.predicateKYCProvider)), true);

        assertEq(soulboundToken.owner(), WALLETS.lowValueOwner);
    }

    function _assertPredicateSanctionsProviderConfiguration() internal {
        PredicateConfiguration memory predicateConfiguration = CONFIGURATION.getPredicateConfiguration();
        PredicateProvider predicateSanctionsProvider = PredicateProvider(deployedContracts.predicateSanctionsProvider);

        assertEq(predicateSanctionsProvider.consumer(), address(deployedContracts.soulboundToken));

        assertEq(predicateSanctionsProvider.getPolicy(), predicateConfiguration.addressScreeningPolicyId);
        assertEq(predicateSanctionsProvider.getPredicateManager(), predicateConfiguration.managerAddress);

        assertEq(predicateSanctionsProvider.owner(), WALLETS.lowValueOwner);
    }

    function _assertPredicateSanctionsProviderSaleConfiguration() internal {
        PredicateConfiguration memory predicateConfiguration = CONFIGURATION.getPredicateConfiguration();
        PredicateProvider predicateSanctionsProviderSale =
            PredicateProvider(deployedContracts.predicateSanctionsProviderSale);

        assertEq(predicateSanctionsProviderSale.consumer(), address(deployedContracts.genesisSequencerSale));

        assertEq(predicateSanctionsProviderSale.getPolicy(), predicateConfiguration.addressScreeningPolicyId);
        assertEq(predicateSanctionsProviderSale.getPredicateManager(), predicateConfiguration.managerAddress);

        assertEq(predicateSanctionsProviderSale.owner(), WALLETS.lowValueOwner);
    }

    function _assertPredicateKYCProviderConfiguration() internal {
        PredicateConfiguration memory predicateConfiguration = CONFIGURATION.getPredicateConfiguration();
        PredicateProvider predicateKYCProvider = PredicateProvider(deployedContracts.predicateKYCProvider);

        assertEq(predicateKYCProvider.consumer(), address(deployedContracts.soulboundToken));

        assertEq(predicateKYCProvider.getPolicy(), predicateConfiguration.kycPolicyId);
        assertEq(predicateKYCProvider.getPredicateManager(), predicateConfiguration.managerAddress);

        assertEq(predicateKYCProvider.owner(), WALLETS.lowValueOwner);
    }

    function _assertZkPassportProviderConfiguration() internal {
        ZkPassportConfiguration memory zkPassportConfiguration = CONFIGURATION.getZkPassportConfiguration();
        ZKPassportProvider zkPassportProvider = ZKPassportProvider(deployedContracts.zkPassportProvider);

        assertEq(zkPassportProvider.consumer(), address(deployedContracts.soulboundToken));
        assertEq(address(zkPassportProvider.zkPassportVerifier()), zkPassportConfiguration.verifierAddress);
        assertEq(zkPassportProvider.domain(), zkPassportConfiguration.domain);
        assertEq(zkPassportProvider.scope(), zkPassportConfiguration.scope);

        assertEq(zkPassportProvider.owner(), WALLETS.lowValueOwner);
    }
}
