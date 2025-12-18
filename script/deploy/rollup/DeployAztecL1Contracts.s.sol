// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

import {Vm} from "forge-std/Vm.sol";
import {TestBase} from "@aztec-test/base/Base.sol";
import {Rollup} from "@aztec/core/Rollup.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {TestERC20} from "@aztec/mock/TestERC20.sol";
import {GSE} from "@aztec/governance/GSE.sol";
import {Registry} from "@aztec/governance/Registry.sol";
import {GovernanceProposer} from "@aztec/governance/proposer/GovernanceProposer.sol";
import {Governance} from "@aztec/governance/Governance.sol";
import {Configuration as GovernanceConfiguration} from "@aztec/governance/interfaces/IGovernance.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {Address} from "@oz/utils/Address.sol";
import {HonkVerifier} from "@aztec/HonkVerifier.sol";
import {CoinIssuer, IMintableERC20} from "@aztec/governance/CoinIssuer.sol";
import {FlushRewarder} from "@aztec/periphery/FlushRewarder.sol";
import {GenesisState} from "@aztec/core/interfaces/IRollup.sol";
import {RollupConfigInput} from "@aztec/core/interfaces/IRollup.sol";
import {IVerifier} from "@aztec/core/interfaces/IVerifier.sol";
import {IHaveVersion} from "@aztec/governance/interfaces/IRegistry.sol";
import {IInstance} from "@aztec/core/interfaces/IInstance.sol";
import {Timestamp} from "@aztec/shared/libraries/TimeMath.sol";
import {FoundationPayload} from "../FoundationPayload.sol";
import {RewardDistributor} from "@aztec/governance/RewardDistributor.sol";
import {ProtocolTreasury} from "src/ProtocolTreasury.sol";

import {MockATPRegistry} from "test/mocks/MockAtpRegistry.sol";
import {FoundationWallets} from "../CollectiveDeploy.s.sol";

import {RewardConfig, Bps} from "@aztec/core/libraries/rollup/RewardLib.sol";
import {IBoosterCore, IBooster, RewardBooster, RewardBoostConfig} from "@aztec/core/reward-boost/RewardBooster.sol";
import {
    CompressedStakingQueueConfig,
    StakingQueueConfigLib,
    StakingQueueConfig
} from "@aztec/core/libraries/compressed-data/StakingQueueConfig.sol";
import {Slasher} from "@aztec/core/slashing/Slasher.sol";
import {TallySlashingProposer} from "@aztec/core/slashing/TallySlashingProposer.sol";

import {
    AztecConfiguration,
    ConfigurationVariant,
    GseConfiguration,
    GovernanceProposerConfiguration,
    CoinIssuerConfiguration,
    ProtocolTreasuryConfiguration,
    FlushRewardConfiguration
} from "./AztecConfiguration.sol";

contract DeployAztecL1Contracts is TestBase {
    using Address for address;

    FoundationWallets internal WALLETS;
    AztecConfiguration internal AZTEC_CONFIGURATION;

    IERC20 public FEE_ASSET_CONTRACT;
    IERC20 public STAKING_ASSET_CONTRACT;
    GSE public GSE_CONTRACT;
    Registry public REGISTRY_CONTRACT;
    RewardDistributor public REWARD_DISTRIBUTOR_CONTRACT;
    GovernanceProposer public GOVERNANCE_PROPOSER_CONTRACT;
    Governance public GOVERNANCE_CONTRACT;
    CoinIssuer public COIN_ISSUER_CONTRACT;
    ProtocolTreasury public PROTOCOL_TREASURY_CONTRACT;
    FlushRewarder public FLUSH_REWARDER_CONTRACT;
    IVerifier public VERIFIER_CONTRACT;
    Rollup public ROLLUP_CONTRACT;
    FoundationPayload public FOUNDATION_PAYLOAD_CONTRACT;

    function setEnv(ConfigurationVariant _variant, FoundationWallets memory _foundationWallets, address _asset)
        public
    {
        AZTEC_CONFIGURATION = new AztecConfiguration(_variant);
        WALLETS = _foundationWallets;
        FEE_ASSET_CONTRACT = IERC20(_asset);
        STAKING_ASSET_CONTRACT = IERC20(_asset);
    }

    function getRewardDistributorFunding() public view returns (uint256) {
        return AZTEC_CONFIGURATION.getRewardDistributorFunding();
    }

    function getFlushRewardInitialFunding() public view returns (uint256) {
        return AZTEC_CONFIGURATION.getFlushRewardConfiguration().initialFundingAmount;
    }

    function run() public {
        deployAztecContracts();
    }

    function deployAztecContracts() public {
        deployGSE(); // N-1
        deployRegistry(); // N-2
        deployGovernanceProposer(); // N-3
        deployGovernance(); // N-4
        deployDateGatedRelayer(); // G-5
        deployFoundationPayload();

        deployCoinIssuer(); // N-6

        deployAndAddRollup(); // N-8, N-9, N-10

        deployFlushRewarder();

        handoverRegistry(); // G-1
        handoverGSE(); // G-2

        _assertAccessControl();
        _assertRollupConfigurations();
        _assertGovernanceConfiguration();
    }

    function deployFoundationPayload() public {
        vm.broadcast(WALLETS.deployer);
        FOUNDATION_PAYLOAD_CONTRACT = new FoundationPayload(WALLETS.deployer);
    }

    function deployGSE() public {
        GseConfiguration memory gseConfiguration = AZTEC_CONFIGURATION.getGseConfiguration();

        vm.broadcast(WALLETS.deployer);
        GSE_CONTRACT = new GSE(
            WALLETS.deployer,
            STAKING_ASSET_CONTRACT,
            gseConfiguration.activationThreshold,
            gseConfiguration.ejectionThreshold
        );
    }

    function handoverGSE() public {
        vm.broadcast(WALLETS.deployer);
        GSE_CONTRACT.transferOwnership(address(GOVERNANCE_CONTRACT));
    }

    function deployRegistry() public {
        vm.broadcast(WALLETS.deployer);
        REGISTRY_CONTRACT = new Registry(WALLETS.deployer, FEE_ASSET_CONTRACT);
        REWARD_DISTRIBUTOR_CONTRACT = RewardDistributor(address(REGISTRY_CONTRACT.getRewardDistributor()));
    }

    function handoverRegistry() public {
        vm.broadcast(WALLETS.deployer);
        REGISTRY_CONTRACT.transferOwnership(address(GOVERNANCE_CONTRACT));
    }

    function deployGovernanceProposer() public {
        GovernanceProposerConfiguration memory governanceProposerConfiguration =
            AZTEC_CONFIGURATION.getGovernanceProposerConfiguration();
        vm.broadcast(WALLETS.deployer);
        GOVERNANCE_PROPOSER_CONTRACT = new GovernanceProposer(
            REGISTRY_CONTRACT,
            GSE_CONTRACT,
            governanceProposerConfiguration.quorum,
            governanceProposerConfiguration.roundSize
        );
    }

    function deployGovernance() public {
        GovernanceConfiguration memory governanceConfiguration = AZTEC_CONFIGURATION.getGovernanceConfiguration();
        vm.broadcast(WALLETS.deployer);
        GOVERNANCE_CONTRACT = new Governance(
            STAKING_ASSET_CONTRACT,
            address(GOVERNANCE_PROPOSER_CONTRACT),
            address(0), // 0 to allow anyone to deposit.
            governanceConfiguration
        );

        vm.broadcast(WALLETS.deployer);
        GSE_CONTRACT.setGovernance(GOVERNANCE_CONTRACT);
    }

    function deployCoinIssuer() public {
        CoinIssuerConfiguration memory coinIssuerConfiguration = AZTEC_CONFIGURATION.getCoinIssuerConfiguration();
        vm.broadcast(WALLETS.deployer);
        COIN_ISSUER_CONTRACT = new CoinIssuer(
            IMintableERC20(address(FEE_ASSET_CONTRACT)),
            coinIssuerConfiguration.coinIssuerRate,
            address(FOUNDATION_PAYLOAD_CONTRACT)
        );
    }

    function deployDateGatedRelayer() public {
        ProtocolTreasuryConfiguration memory protocolTreasuryConfiguration =
            AZTEC_CONFIGURATION.getProtocolTreasuryConfiguration();

        address insiderAtpRegistry = 0xD938bE4A2cB41105Bc2FbE707dca124A2e5d0c80;
        if (block.chainid != 1) {
            // If we are not on mainnet, we have to deploy something we can use.
            vm.broadcast(WALLETS.deployer);
            insiderAtpRegistry = address(new MockATPRegistry(protocolTreasuryConfiguration.gatedUntil));
        }

        vm.broadcast(WALLETS.deployer);
        PROTOCOL_TREASURY_CONTRACT = new ProtocolTreasury(
            address(GOVERNANCE_CONTRACT), insiderAtpRegistry, protocolTreasuryConfiguration.gatedUntil
        );
    }

    function deployAndAddRollup() public {
        vm.broadcast(WALLETS.deployer);
        VERIFIER_CONTRACT = IVerifier(address(new HonkVerifier()));

        GenesisState memory genesisState = AZTEC_CONFIGURATION.getGenesisState();

        RollupConfigInput memory rollupConfig =
            AZTEC_CONFIGURATION.getRollupConfiguration(REGISTRY_CONTRACT.getRewardDistributor());

        vm.broadcast(WALLETS.deployer);
        ROLLUP_CONTRACT = new Rollup(
            FEE_ASSET_CONTRACT,
            STAKING_ASSET_CONTRACT,
            GSE_CONTRACT,
            VERIFIER_CONTRACT,
            address(GOVERNANCE_CONTRACT),
            genesisState,
            rollupConfig
        );

        vm.broadcast(WALLETS.deployer);
        REGISTRY_CONTRACT.addRollup(IHaveVersion(address(ROLLUP_CONTRACT)));

        vm.broadcast(WALLETS.deployer);
        GSE_CONTRACT.addRollup(address(ROLLUP_CONTRACT));
    }

    function deployFlushRewarder() public {
        FlushRewardConfiguration memory flushRewardConfiguration = AZTEC_CONFIGURATION.getFlushRewardConfiguration();

        vm.broadcast(WALLETS.deployer);
        FLUSH_REWARDER_CONTRACT = new FlushRewarder(
            address(GOVERNANCE_CONTRACT),
            IInstance(address(ROLLUP_CONTRACT)),
            FEE_ASSET_CONTRACT,
            flushRewardConfiguration.rewardPerInsertion
        );
    }

    function _assertAccessControl() internal {
        assertEq(Ownable(address(GSE_CONTRACT)).owner(), address(GOVERNANCE_CONTRACT), "invalid gse owner");
        assertEq(address(GSE_CONTRACT.getGovernance()), address(GOVERNANCE_CONTRACT), "invalid gse governance");
        assertEq(Ownable(address(REGISTRY_CONTRACT)).owner(), address(GOVERNANCE_CONTRACT), "invalid registry owner");
        assertEq(
            Ownable(address(FLUSH_REWARDER_CONTRACT)).owner(),
            address(GOVERNANCE_CONTRACT),
            "invalid flush rewarder owner"
        );
        assertEq(
            address(REWARD_DISTRIBUTOR_CONTRACT.REGISTRY()),
            address(REGISTRY_CONTRACT),
            "invalid reward distributor registry"
        );
        assertEq(
            Ownable(address(COIN_ISSUER_CONTRACT)).owner(),
            address(FOUNDATION_PAYLOAD_CONTRACT),
            "invalid coin issuer owner"
        );
        assertEq(
            Ownable(address(PROTOCOL_TREASURY_CONTRACT)).owner(),
            address(GOVERNANCE_CONTRACT),
            "invalid protocol treasury relayer owner"
        );
        assertEq(
            Ownable(address(FOUNDATION_PAYLOAD_CONTRACT)).owner(),
            address(WALLETS.deployer),
            "invalid foundation payload owner"
        );
        assertEq(Ownable(address(FEE_ASSET_CONTRACT)).owner(), address(WALLETS.tokenOwner), "invalid token owner");
        assertEq(Ownable(address(STAKING_ASSET_CONTRACT)).owner(), address(WALLETS.tokenOwner), "invalid token owner");
    }

    function _assertRollupConfigurations() internal {
        // Check the rollup configuration
        assertEq(ROLLUP_CONTRACT.getManaLimit(), 0);
        assertEq(ROLLUP_CONTRACT.getProvenBlockNumber(), 0);
        assertEq(ROLLUP_CONTRACT.getPendingBlockNumber(), 0);
        assertEq(ROLLUP_CONTRACT.archiveAt(0), AZTEC_CONFIGURATION.getGenesisState().genesisArchiveRoot);
        assertEq(address(ROLLUP_CONTRACT.getFeeAsset()), address(STAKING_ASSET_CONTRACT));
        assertEq(address(ROLLUP_CONTRACT.getStakingAsset()), address(STAKING_ASSET_CONTRACT));
        assertEq(
            ROLLUP_CONTRACT.getVersion(),
            AZTEC_CONFIGURATION.getRollupConfiguration(REWARD_DISTRIBUTOR_CONTRACT).version
        );

        // Check the registry and gse configuration
        assertEq(REGISTRY_CONTRACT.numberOfVersions(), 1);
        assertEq(address(REGISTRY_CONTRACT.getCanonicalRollup()), address(ROLLUP_CONTRACT));
        assertEq(address(REGISTRY_CONTRACT.getRollup(0)), address(ROLLUP_CONTRACT));

        _assertRewardConfiguration();
        _assertSlasherConfig();
        _assertValidatorSelectionConfiguration();
    }

    function _assertRewardConfiguration() internal {
        RewardConfig memory rewardConfig = ROLLUP_CONTRACT.getRewardConfig();
        RewardConfig memory expectedConfig = AZTEC_CONFIGURATION.getRewardConfiguration(REWARD_DISTRIBUTOR_CONTRACT);

        assertEq(
            Timestamp.unwrap(ROLLUP_CONTRACT.getEarliestRewardsClaimableTimestamp()),
            Timestamp.unwrap(AZTEC_CONFIGURATION.getEarliestRewardsClaimableTimestamp())
        );

        assertEq(address(rewardConfig.rewardDistributor), address(REWARD_DISTRIBUTOR_CONTRACT));
        assertEq(Bps.unwrap(rewardConfig.sequencerBps), Bps.unwrap(expectedConfig.sequencerBps));
        assertEq(rewardConfig.blockReward, expectedConfig.blockReward);

        assertEq(address(RewardBooster(address(rewardConfig.booster)).ROLLUP()), address(ROLLUP_CONTRACT));

        RewardBoostConfig memory rewardBoostConfig = IBooster(address(rewardConfig.booster)).getConfig();
        RewardBoostConfig memory expectedBoostConfig = AZTEC_CONFIGURATION.getRewardBoostConfiguration();

        assertEq(rewardBoostConfig.increment, expectedBoostConfig.increment);
        assertEq(rewardBoostConfig.maxScore, expectedBoostConfig.maxScore);
        assertEq(rewardBoostConfig.a, expectedBoostConfig.a);
        assertEq(rewardBoostConfig.minimum, expectedBoostConfig.minimum);
        assertEq(rewardBoostConfig.k, expectedBoostConfig.k);
    }

    function _assertValidatorSelectionConfiguration() internal {
        assertEq(address(GSE_CONTRACT.getLatestRollup()), address(ROLLUP_CONTRACT));
        assertEq(GSE_CONTRACT.ACTIVATION_THRESHOLD(), AZTEC_CONFIGURATION.getGseConfiguration().activationThreshold);
        assertEq(GSE_CONTRACT.EJECTION_THRESHOLD(), AZTEC_CONFIGURATION.getGseConfiguration().ejectionThreshold);
        assertEq(address(GSE_CONTRACT.ASSET()), address(STAKING_ASSET_CONTRACT));
        assertEq(address(GSE_CONTRACT.owner()), address(GOVERNANCE_CONTRACT));
        assertEq(address(GSE_CONTRACT.getGovernance()), address(GOVERNANCE_CONTRACT));

        RollupConfigInput memory expectedInput = AZTEC_CONFIGURATION.getRollupConfiguration(REWARD_DISTRIBUTOR_CONTRACT);
        assertEq(ROLLUP_CONTRACT.getSlotDuration(), expectedInput.aztecSlotDuration);
        assertEq(ROLLUP_CONTRACT.getEpochDuration(), expectedInput.aztecEpochDuration);
        assertEq(ROLLUP_CONTRACT.getTargetCommitteeSize(), expectedInput.targetCommitteeSize);
        assertEq(ROLLUP_CONTRACT.getLagInEpochs(), expectedInput.lagInEpochs);
        assertEq(ROLLUP_CONTRACT.getProofSubmissionEpochs(), expectedInput.aztecProofSubmissionEpochs);
        assertEq(ROLLUP_CONTRACT.getLocalEjectionThreshold(), expectedInput.localEjectionThreshold);
        assertEq(Timestamp.unwrap(ROLLUP_CONTRACT.getExitDelay()), expectedInput.exitDelaySeconds);

        // NOTE: We raw load the entry queue configuration from storage.
        bytes32 slot = bytes32(uint256(keccak256("aztec.core.staking.storage")) + 4);

        StakingQueueConfig memory value = StakingQueueConfigLib.decompress(
            CompressedStakingQueueConfig.wrap(uint256(vm.load(address(ROLLUP_CONTRACT), slot)))
        );
        StakingQueueConfig memory expectedQueueConfig = expectedInput.stakingQueueConfig;

        assertEq(value.bootstrapValidatorSetSize, expectedQueueConfig.bootstrapValidatorSetSize);
        assertEq(value.bootstrapFlushSize, expectedQueueConfig.bootstrapFlushSize);
        assertEq(value.normalFlushSizeMin, expectedQueueConfig.normalFlushSizeMin);
        assertEq(value.normalFlushSizeQuotient, expectedQueueConfig.normalFlushSizeQuotient);
        assertEq(value.maxQueueFlushSize, expectedQueueConfig.maxQueueFlushSize);
    }

    function _assertSlasherConfig() internal {
        Slasher slasher = Slasher(ROLLUP_CONTRACT.getSlasher());
        TallySlashingProposer proposer = TallySlashingProposer(slasher.PROPOSER());

        RollupConfigInput memory expectedInput = AZTEC_CONFIGURATION.getRollupConfiguration(REWARD_DISTRIBUTOR_CONTRACT);

        assertEq(slasher.GOVERNANCE(), address(GOVERNANCE_CONTRACT));
        assertEq(slasher.VETOER(), expectedInput.slashingVetoer);
        assertEq(slasher.SLASHING_DISABLE_DURATION(), expectedInput.slashingDisableDuration);

        assertEq(proposer.INSTANCE(), address(ROLLUP_CONTRACT));
        assertEq(address(proposer.SLASHER()), address(slasher));
        assertEq(proposer.SLASH_AMOUNT_SMALL(), expectedInput.slashAmounts[0]);
        assertEq(proposer.SLASH_AMOUNT_MEDIUM(), expectedInput.slashAmounts[1]);
        assertEq(proposer.SLASH_AMOUNT_LARGE(), expectedInput.slashAmounts[2]);
        assertEq(proposer.QUORUM(), expectedInput.slashingQuorum);
        assertEq(proposer.ROUND_SIZE(), expectedInput.slashingRoundSize);
        assertEq(proposer.COMMITTEE_SIZE(), expectedInput.targetCommitteeSize);
        assertEq(proposer.LIFETIME_IN_ROUNDS(), expectedInput.slashingLifetimeInRounds);
        assertEq(proposer.EXECUTION_DELAY_IN_ROUNDS(), expectedInput.slashingExecutionDelayInRounds);
        assertEq(proposer.SLASH_OFFSET_IN_ROUNDS(), expectedInput.slashingOffsetInRounds);
        assertEq(uint256(proposer.SLASHING_PROPOSER_TYPE()), uint256(expectedInput.slasherFlavor));
    }

    function _assertGovernanceConfiguration() internal {
        GovernanceConfiguration memory actual = GOVERNANCE_CONTRACT.getConfiguration();
        GovernanceConfiguration memory expected = AZTEC_CONFIGURATION.getGovernanceConfiguration();

        assertEq(actual.proposeConfig.lockDelay, expected.proposeConfig.lockDelay);
        assertEq(actual.proposeConfig.lockAmount, expected.proposeConfig.lockAmount);

        assertEq(actual.votingDelay, expected.votingDelay);
        assertEq(actual.votingDuration, expected.votingDuration);
        assertEq(actual.executionDelay, expected.executionDelay);
        assertEq(actual.gracePeriod, expected.gracePeriod);
        assertEq(actual.quorum, expected.quorum);
        assertEq(actual.requiredYeaMargin, expected.requiredYeaMargin);
        assertEq(actual.minimumVotes, expected.minimumVotes);

        assertEq(GOVERNANCE_CONTRACT.isAllBeneficiariesAllowed(), true);
    }
}
