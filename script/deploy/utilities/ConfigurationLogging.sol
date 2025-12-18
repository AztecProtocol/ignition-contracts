// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// @todo: showcase parameters of deployed contracts also

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {Ownable2Step} from "@oz/access/Ownable2Step.sol";
import {Rollup} from "@aztec/core/Rollup.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Timestamp} from "@aztec/shared/libraries/TimeMath.sol";
import {RewardConfig, Bps} from "@aztec/core/libraries/rollup/RewardLib.sol";
import {IBoosterCore, IBooster, RewardBooster, RewardBoostConfig} from "@aztec/core/reward-boost/RewardBooster.sol";
import {GSE} from "@aztec/governance/GSE.sol";
import {Slasher} from "@aztec/core/slashing/Slasher.sol";
import {TallySlashingProposer} from "@aztec/core/slashing/TallySlashingProposer.sol";
import {Governance} from "@aztec/governance/Governance.sol";
import {
    CompressedStakingQueueConfig,
    StakingQueueConfigLib,
    StakingQueueConfig
} from "@aztec/core/libraries/compressed-data/StakingQueueConfig.sol";
import {Configuration as GovernanceConfiguration} from "@aztec/governance/interfaces/IGovernance.sol";
import {GovernanceProposer} from "@aztec/governance/proposer/GovernanceProposer.sol";
import {Registry} from "@aztec/governance/Registry.sol";
import {RewardDistributor} from "@aztec/governance/RewardDistributor.sol";
import {Aztec} from "@atp/token/Aztec.sol";
import {FlushRewarder} from "@aztec/periphery/FlushRewarder.sol";
import {GenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";
import {ATPFactory} from "@atp/ATPFactory.sol";
import {Registry as ATPRegistry, StakerVersion} from "@atp/Registry.sol";
import {IgnitionParticipantSoulbound} from "src/soulbound/IgnitionParticipantSoulbound.sol";
import {ZKPassportProvider} from "src/soulbound/providers/ZKPassportProvider.sol";
import {PredicateProvider} from "src/soulbound/providers/PredicateProvider.sol";
import {StakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {SplitsWarehouse} from "@splits/SplitsWarehouse.sol";
import {PullSplitFactory} from "@splits/splitters/pull/PullSplitFactory.sol";
import {ATPWithdrawableAndClaimableStaker} from "src/staking/ATPWithdrawableAndClaimableStaker.sol";
import {VirtualAztecToken} from "src/uniswap-periphery/VirtualAztecToken.sol";
import {ATPFactoryNonces} from "@atp/ATPFactoryNonces.sol";
import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";
import {AztecAuctionHook} from "src/uniswap-periphery/AuctionHook.sol";
import {ILiquidityLauncher} from "@launcher/interfaces/ILiquidityLauncher.sol";
import {IVirtualLBPStrategyBasic} from "src/uniswap-periphery/IVirtualLBPStrategyBasic.sol";
import {GovernanceAcceleratedLock} from "src/uniswap-periphery/GovernanceAcceleratedLock.sol";
import {IContinuousClearingAuctionFactory} from "@twap-auction/interfaces/IContinuousClearingAuctionFactory.sol";
import {Currency} from "@twap-auction/libraries/CurrencyLibrary.sol";
import {
    FoundationPayload,
    FoundationPayloadConfig,
    FoundationAztecConfig,
    FoundationTwapConfig,
    FoundationGenesisSaleConfig,
    TwapGovPayloadConfig,
    ProtocolTreasuryConfig,
    FoundationFundingConfig
} from "../FoundationPayload.sol";

contract ConfigurationLogging is Test {
    uint256 internal constant INDENTION = 48;

    function _loadJson() internal returns (string memory) {
        string memory chainId = vm.toString(block.chainid);
        // Always write to contracts/deployments/ (inside foundry project root)
        // The bootstrap script will copy this to the correct location
        string memory deploymentsDir = vm.envString("DEPLOYMENTS_DIR");
        if (!vm.exists(deploymentsDir)) {
            vm.createDir(deploymentsDir, true);
        }
        string memory inputPath = string.concat(deploymentsDir, "/collective-l1-deployment-", chainId, ".json");

        string memory json = vm.readFile(inputPath);

        return json;
    }

    function log_configuration() public {
        _logGogvernanceConfiguration();
        _logAztecConfiguration();
        _sale();
        _atpFactoryAndRegistry();
        _soulboundTokenAndProviders();
        _stakingRegistry();
        _splitsContracts();
        _auction();
        _foundationPayload();

        _dirstribution();
    }

    function _logGogvernanceConfiguration() public {
        string memory json = _loadJson();

        emit log("=== Governance Configuration ===");

        Aztec asset = Aztec(vm.parseJsonAddress(json, ".stakingAssetAddress"));
        emit log_named_address(_prefix(1, "staking asset"), address(asset));
        emit log_named_string(_prefix(2, "name"), asset.name());
        emit log_named_string(_prefix(2, "symbol"), asset.symbol());
        emit log_named_uint(_prefix(2, "decimals"), asset.decimals());
        emit log_named_address(_prefix(2, "owner"), Ownable(address(asset)).owner());
        emit log_named_decimal_uint(_prefix(2, "total supply"), asset.totalSupply(), 18);
        emit log("");

        GSE gse = GSE(vm.parseJsonAddress(json, ".gseAddress"));
        emit log_named_address(_prefix(1, "gse"), address(gse));
        emit log_named_address(_prefix(2, "owner"), address(gse.owner()));
        emit log_named_address(_prefix(2, "governance"), address(gse.getGovernance()));
        emit log_named_address(_prefix(2, "latest rollup"), address(gse.getLatestRollup()));
        emit log_named_decimal_uint(_prefix(2, "activation threshold"), gse.ACTIVATION_THRESHOLD(), 18);
        emit log_named_decimal_uint(_prefix(2, "ejection threshold"), gse.EJECTION_THRESHOLD(), 18);
        emit log_named_address(_prefix(2, "asset"), address(gse.ASSET()));
        emit log("");

        Governance gov = Governance(vm.parseJsonAddress(json, ".governanceAddress"));
        GovernanceConfiguration memory actual = gov.getConfiguration();

        emit log_named_address(_prefix(1, "governance"), address(gov));
        emit log(_prefix(2, "propose config"));
        emit log_named_uint(_prefix(3, "lock delay"), Timestamp.unwrap(actual.proposeConfig.lockDelay));
        emit log_named_decimal_uint(_prefix(3, "lock amount"), actual.proposeConfig.lockAmount, 18);
        emit log_named_uint(_prefix(2, "voting delay"), Timestamp.unwrap(actual.votingDelay));
        emit log_named_uint(_prefix(2, "voting duration"), Timestamp.unwrap(actual.votingDuration));
        emit log_named_uint(_prefix(2, "execution delay"), Timestamp.unwrap(actual.executionDelay));
        emit log_named_uint(_prefix(2, "grace period"), Timestamp.unwrap(actual.gracePeriod));
        emit log_named_decimal_uint(_prefix(2, "required yea margin (%)"), actual.requiredYeaMargin, 16);
        emit log_named_decimal_uint(_prefix(2, "minimum votes"), actual.minimumVotes, 18);
        emit log_named_address(_prefix(2, "asset"), address(gov.ASSET()));
        emit log_named_address(_prefix(2, "governance proposer"), gov.governanceProposer());
        emit log("");

        GovernanceProposer proposer = GovernanceProposer(vm.parseJsonAddress(json, ".governanceProposerAddress"));
        emit log_named_address(_prefix(1, "governance proposer"), address(proposer));
        emit log_named_uint(_prefix(2, "quorum size"), proposer.QUORUM_SIZE());
        emit log_named_uint(_prefix(2, "round size"), proposer.ROUND_SIZE());
        emit log_named_uint(_prefix(2, "lifetim in rounds"), proposer.LIFETIME_IN_ROUNDS());
        emit log_named_uint(_prefix(2, "execution delay in rounds"), proposer.EXECUTION_DELAY_IN_ROUNDS());
        emit log_named_address(_prefix(2, "governance"), proposer.getGovernance());
        emit log_named_address(_prefix(2, "instance"), proposer.getInstance());
        emit log_named_address(_prefix(2, "gse"), address(proposer.GSE()));
        emit log_named_address(_prefix(2, "registry"), address(proposer.REGISTRY()));
        emit log("");

        Registry registry = Registry(vm.parseJsonAddress(json, ".registryAddress"));
        emit log_named_address(_prefix(1, "registry"), address(registry));
        emit log_named_address(_prefix(2, "reward distributor"), address(registry.getRewardDistributor()));
        emit log_named_address(_prefix(2, "governance"), address(registry.getGovernance()));
        emit log_named_address(_prefix(2, "owner"), address(registry.owner()));
        emit log_named_uint(_prefix(2, "number of versions"), registry.numberOfVersions());
        emit log_named_address(_prefix(2, "canonical rollup"), address(registry.getCanonicalRollup()));
        emit log("");

        RewardDistributor rewardDistributor = RewardDistributor(vm.parseJsonAddress(json, ".rewardDistributorAddress"));
        emit log_named_address(_prefix(1, "reward distributor"), address(rewardDistributor));
        emit log_named_address(_prefix(2, "asset"), address(rewardDistributor.ASSET()));
        emit log_named_address(_prefix(2, "registry"), address(rewardDistributor.REGISTRY()));
        emit log_named_decimal_uint(_prefix(2, "aztec balance"), asset.balanceOf(address(rewardDistributor)), 18);
        emit log("");
    }

    function _logAztecConfiguration() internal {
        string memory json = _loadJson();
        Rollup rollup = Rollup(vm.parseJsonAddress(json, ".rollupAddress"));
        Aztec asset = Aztec(vm.parseJsonAddress(json, ".stakingAssetAddress"));

        emit log("=== Aztec Configuration ===");

        // TODO: registry
        //        emit log(_prefix(2, "Rollup registry"));
        //        emit log_named_uint(_prefix(4, "number of versions"), )

        // NOTE: Rollup
        emit log_named_address(_prefix(1, "Rollup"), address(rollup));
        emit log_named_address(_prefix(2, "owner"), Ownable(address(rollup)).owner());
        emit log_named_address(_prefix(2, "fee asset"), address(rollup.getFeeAsset()));
        emit log_named_address(_prefix(2, "staking asset"), address(rollup.getFeeAsset()));

        emit log(_prefix(2, "core"));
        emit log_named_decimal_uint(_prefix(3, "mana limit"), rollup.getManaLimit(), 6);
        emit log_named_uint(_prefix(3, "proven block number"), rollup.getProvenBlockNumber());
        emit log_named_uint(_prefix(3, "pending block number"), rollup.getPendingBlockNumber());
        emit log_named_uint(_prefix(3, "version"), rollup.getVersion());
        emit log_named_bytes32(_prefix(3, "genesis archive root"), rollup.archiveAt(0));

        // TODO: Need some of the other things from the genesis state.

        RewardConfig memory rewardConfig = rollup.getRewardConfig();
        emit log(_prefix(2, "reward configuration"));
        emit log_named_uint(
            _prefix(3, "earliest reward claimable timestamp"),
            Timestamp.unwrap(rollup.getEarliestRewardsClaimableTimestamp())
        );
        emit log_named_decimal_uint(_prefix(3, "sequencer %"), Bps.unwrap(rewardConfig.sequencerBps), 2);
        emit log_named_decimal_uint(_prefix(3, "block reward"), rewardConfig.blockReward, 18);
        emit log_named_address(_prefix(3, "reward distributor"), address(rewardConfig.rewardDistributor));
        emit log_named_address(_prefix(3, "reward booster"), address(rewardConfig.booster));
        RewardBoostConfig memory rewardBoostConfig = IBooster(address(rewardConfig.booster)).getConfig();
        emit log_named_decimal_uint(_prefix(4, "increment"), rewardBoostConfig.increment, 5);
        emit log_named_decimal_uint(_prefix(4, "maxScore"), rewardBoostConfig.maxScore, 5);
        emit log_named_decimal_uint(_prefix(4, "a"), rewardBoostConfig.a, 5);
        emit log_named_decimal_uint(_prefix(4, "minimum"), rewardBoostConfig.minimum, 5);
        emit log_named_decimal_uint(_prefix(4, "k"), rewardBoostConfig.k, 5);

        emit log(_prefix(2, "Validator Selection"));
        emit log_named_address(_prefix(3, "gse"), address(rollup.getGSE()));
        emit log_named_decimal_uint(_prefix(3, "local ejection threshold"), rollup.getLocalEjectionThreshold(), 18);
        emit log_named_uint(_prefix(3, "slot duration"), rollup.getSlotDuration());
        emit log_named_uint(_prefix(3, "epoch duration"), rollup.getEpochDuration());
        emit log_named_uint(_prefix(3, "lag in epochs"), rollup.getLagInEpochs());
        emit log_named_uint(_prefix(3, "target committee size"), rollup.getTargetCommitteeSize());
        emit log_named_uint(_prefix(3, "proof submission epochs"), rollup.getProofSubmissionEpochs());
        emit log_named_uint(_prefix(3, "exit delay"), Timestamp.unwrap(rollup.getExitDelay()));

        bytes32 slot = bytes32(uint256(keccak256("aztec.core.staking.storage")) + 4);
        StakingQueueConfig memory value =
            StakingQueueConfigLib.decompress(CompressedStakingQueueConfig.wrap(uint256(vm.load(address(rollup), slot))));
        emit log(_prefix(2, "staking queue configuration"));
        emit log_named_uint(_prefix(3, "bootstrap validator set size"), value.bootstrapValidatorSetSize);
        emit log_named_uint(_prefix(3, "bootstrap flush size"), value.bootstrapFlushSize);
        emit log_named_uint(_prefix(3, "normal flush size min"), value.normalFlushSizeMin);
        emit log_named_uint(_prefix(3, "normal flush size quotient"), value.normalFlushSizeQuotient);
        emit log_named_uint(_prefix(3, "max queue flush size"), value.maxQueueFlushSize);

        Slasher slasher = Slasher(rollup.getSlasher());
        emit log_named_address(_prefix(2, "slasher"), address(slasher));
        emit log_named_address(_prefix(3, "vetoer"), slasher.VETOER());
        emit log_named_address(_prefix(3, "governance"), slasher.GOVERNANCE());
        emit log_named_uint(_prefix(3, "slashing disable duration"), slasher.SLASHING_DISABLE_DURATION());

        TallySlashingProposer tallyProposer = TallySlashingProposer(slasher.PROPOSER());
        emit log_named_address(_prefix(3, "slashing proposer"), address(tallyProposer));
        emit log_named_address(_prefix(4, "instance"), address(tallyProposer.INSTANCE()));
        emit log_named_decimal_uint(_prefix(4, "slash amount small"), tallyProposer.SLASH_AMOUNT_SMALL(), 18);
        emit log_named_decimal_uint(_prefix(4, "slash amount medium"), tallyProposer.SLASH_AMOUNT_MEDIUM(), 18);
        emit log_named_decimal_uint(_prefix(4, "slash amount large"), tallyProposer.SLASH_AMOUNT_LARGE(), 18);
        emit log_named_uint(_prefix(4, "quorum"), tallyProposer.QUORUM());
        emit log_named_uint(_prefix(4, "round size"), tallyProposer.ROUND_SIZE());
        emit log_named_uint(_prefix(4, "committee size"), tallyProposer.COMMITTEE_SIZE());
        emit log_named_uint(_prefix(4, "lifetime in rounds"), tallyProposer.LIFETIME_IN_ROUNDS());
        emit log_named_uint(_prefix(4, "execution delay in rounds"), tallyProposer.EXECUTION_DELAY_IN_ROUNDS());
        emit log_named_uint(_prefix(4, "slash offset in rounds"), tallyProposer.SLASH_OFFSET_IN_ROUNDS());
        emit log_named_uint(_prefix(4, "slashing proposer type"), uint256(tallyProposer.SLASHING_PROPOSER_TYPE()));
        emit log("");

        FlushRewarder flushRewarder = FlushRewarder(vm.parseJsonAddress(json, ".flushRewarderAddress"));
        emit log_named_address(_prefix(1, "flush rewarder"), address(flushRewarder));
        emit log_named_address(_prefix(2, "rollup"), address(flushRewarder.ROLLUP()));
        emit log_named_address(_prefix(2, "asset"), address(flushRewarder.REWARD_ASSET()));
        emit log_named_decimal_uint(_prefix(2, "reward per insertion"), flushRewarder.rewardPerInsertion(), 18);
        emit log_named_decimal_uint(_prefix(2, "aztec balance"), asset.balanceOf(address(flushRewarder)), 18);
        emit log("");
    }

    function _sale() internal {
        string memory json = _loadJson();

        GenesisSequencerSale gss = GenesisSequencerSale(payable(vm.parseJsonAddress(json, ".genesisSequencerSale")));
        Aztec asset = Aztec(vm.parseJsonAddress(json, ".stakingAssetAddress"));

        emit log("=== Genesis Sequencer Sale Configuration ===");

        emit log_named_address(_prefix(1, "genesis sequencer sale"), address(gss));
        emit log_named_address(_prefix(2, "owner"), Ownable(address(gss)).owner());

        emit log(_prefix(2, "sale parameters"));
        emit log_named_uint(_prefix(3, "purchases per address"), gss.PURCHASES_PER_ADDRESS());
        emit log_named_decimal_uint(_prefix(3, "token lot size"), gss.TOKEN_LOT_SIZE(), 18);
        emit log_named_decimal_uint(_prefix(3, "sale token purchase amount"), gss.SALE_TOKEN_PURCHASE_AMOUNT(), 18);
        emit log_named_decimal_uint(_prefix(3, "price per lot (ETH)"), gss.pricePerLot(), 18);
        emit log_named_decimal_uint(_prefix(3, "purchase cost in ETH"), gss.getPurchaseCostInEth(), 18);

        emit log(_prefix(2, "sale timing"));
        emit log_named_uint(_prefix(3, "sale start time"), gss.saleStartTime());
        emit log_named_uint(_prefix(3, "sale end time"), gss.saleEndTime());
        emit log_named_string(_prefix(3, "sale enabled"), gss.saleEnabled() ? "true" : "false");
        emit log_named_string(_prefix(3, "sale active"), gss.isSaleActive() ? "true" : "false");

        emit log(_prefix(2, "contracts"));
        emit log_named_address(_prefix(3, "ATP factory"), address(gss.ATP_FACTORY()));
        emit log_named_address(_prefix(3, "sale token"), address(gss.SALE_TOKEN()));
        emit log_named_address(_prefix(3, "soulbound token"), address(gss.SOULBOUND_TOKEN()));
        emit log_named_address(_prefix(3, "address screening provider"), gss.addressScreeningProvider());

        emit log(_prefix(2, "balances"));
        emit log_named_decimal_uint(_prefix(3, "sale contract token balance"), asset.balanceOf(address(gss)), 18);
        emit log_named_decimal_uint(_prefix(3, "sale contract ETH balance"), address(gss).balance, 18);
        emit log("");
    }

    function _atpFactoryAndRegistry() internal {
        string memory json = _loadJson();

        ATPFactory atpFactory = ATPFactory(vm.parseJsonAddress(json, ".atpFactory"));
        ATPRegistry atpRegistry = ATPRegistry(vm.parseJsonAddress(json, ".atpRegistry"));

        emit log("=== ATP Factory & Registry Configuration (Sale) ===");

        emit log_named_address(_prefix(1, "ATP factory (sale)"), address(atpFactory));
        emit log_named_address(_prefix(2, "owner"), Ownable(address(atpFactory)).owner());
        emit log_named_address(_prefix(2, "pending owner"), Ownable2Step(address(atpFactory)).pendingOwner());
        emit log_named_address(_prefix(2, "token"), address(atpFactory.getToken()));
        emit log_named_address(_prefix(2, "registry"), address(atpFactory.getRegistry()));
        emit log_named_string(
            _prefix(2, "genesis sale is minter"),
            atpFactory.minter(vm.parseJsonAddress(json, ".genesisSequencerSale")) ? "true" : "false"
        );
        emit log("");

        emit log_named_address(_prefix(1, "ATP registry (sale)"), address(atpRegistry));
        emit log_named_address(_prefix(2, "owner"), Ownable(address(atpRegistry)).owner());
        emit log_named_address(_prefix(2, "pending owner"), Ownable2Step(address(atpRegistry)).pendingOwner());

        emit log(_prefix(2, "global lock params"));
        emit log_named_uint(_prefix(3, "cliff duration"), atpRegistry.getGlobalLockParams().cliffDuration);
        emit log_named_uint(_prefix(3, "lock duration"), atpRegistry.getGlobalLockParams().lockDuration);
        emit log_named_uint(_prefix(2, "execute allowed at"), atpRegistry.getExecuteAllowedAt());
        emit log_named_uint(_prefix(2, "next staker version"), StakerVersion.unwrap(atpRegistry.getNextStakerVersion()));

        emit log(_prefix(2, "staker implementations"));
        address stakerV1 = atpRegistry.getStakerImplementation(StakerVersion.wrap(1));
        emit log_named_address(_prefix(3, "version 1 (withdrawable & claimable)"), stakerV1);

        ATPWithdrawableAndClaimableStaker staker = ATPWithdrawableAndClaimableStaker(stakerV1);
        emit log_named_uint(_prefix(4, "withdrawal timestamp"), staker.WITHDRAWAL_TIMESTAMP());
        emit log("");
    }

    function _soulboundTokenAndProviders() internal {
        string memory json = _loadJson();

        IgnitionParticipantSoulbound soulbound =
            IgnitionParticipantSoulbound(vm.parseJsonAddress(json, ".soulboundToken"));
        ZKPassportProvider zkPassportProvider = ZKPassportProvider(vm.parseJsonAddress(json, ".zkPassportProvider"));
        PredicateProvider predicateSanctionsProvider =
            PredicateProvider(vm.parseJsonAddress(json, ".predicateSanctionsProvider"));
        PredicateProvider predicateKYCProvider = PredicateProvider(vm.parseJsonAddress(json, ".predicateKYCProvider"));
        PredicateProvider predicateSanctionsProviderSale =
            PredicateProvider(vm.parseJsonAddress(json, ".predicateSanctionsProviderSale"));

        emit log("=== Soulbound Token Configuration ===");

        emit log_named_address(_prefix(1, "soulbound token"), address(soulbound));
        emit log_named_address(_prefix(2, "owner"), Ownable(address(soulbound)).owner());
        emit log_named_address(_prefix(2, "token sale address"), soulbound.tokenSaleAddress());
        emit log_named_address(_prefix(2, "address screening provider"), soulbound.addressScreeningProvider());
        emit log_named_uint(_prefix(2, "deployment block"), vm.parseJsonUint(json, ".soulboundTokenDeploymentBlock"));

        emit log(_prefix(2, "identity providers"));
        emit log_named_string(
            _prefix(3, "zkPassport provider"),
            soulbound.identityProviders(address(zkPassportProvider)) ? "true" : "false"
        );
        emit log_named_address(_prefix(4, "address"), address(zkPassportProvider));
        emit log_named_string(
            _prefix(3, "predicate KYC provider"),
            soulbound.identityProviders(address(predicateKYCProvider)) ? "true" : "false"
        );
        emit log_named_address(_prefix(4, "address"), address(predicateKYCProvider));
        emit log("");

        emit log("=== Provider Configurations ===");

        emit log_named_address(_prefix(1, "ZKPassport provider"), address(zkPassportProvider));
        emit log_named_address(_prefix(2, "owner"), Ownable(address(zkPassportProvider)).owner());
        emit log_named_address(_prefix(2, "consumer"), zkPassportProvider.consumer());
        emit log_named_address(_prefix(2, "verifier"), address(zkPassportProvider.zkPassportVerifier()));
        emit log_named_string(_prefix(2, "domain"), zkPassportProvider.domain());
        emit log_named_string(_prefix(2, "scope"), zkPassportProvider.scope());
        emit log("");

        emit log_named_address(_prefix(1, "predicate sanctions provider"), address(predicateSanctionsProvider));
        emit log_named_address(_prefix(2, "owner"), Ownable(address(predicateSanctionsProvider)).owner());
        emit log_named_address(_prefix(2, "consumer"), predicateSanctionsProvider.consumer());
        emit log_named_address(_prefix(2, "predicate manager"), predicateSanctionsProvider.getPredicateManager());
        emit log_named_string(_prefix(2, "policy"), predicateSanctionsProvider.getPolicy());
        emit log("");

        emit log_named_address(_prefix(1, "predicate KYC provider"), address(predicateKYCProvider));
        emit log_named_address(_prefix(2, "owner"), Ownable(address(predicateKYCProvider)).owner());
        emit log_named_address(_prefix(2, "consumer"), predicateKYCProvider.consumer());
        emit log_named_address(_prefix(2, "predicate manager"), predicateKYCProvider.getPredicateManager());
        emit log_named_string(_prefix(2, "policy"), predicateKYCProvider.getPolicy());
        emit log("");

        emit log_named_address(
            _prefix(1, "predicate sanctions provider (sale)"), address(predicateSanctionsProviderSale)
        );
        emit log_named_address(_prefix(2, "owner"), Ownable(address(predicateSanctionsProviderSale)).owner());
        emit log_named_address(_prefix(2, "consumer"), predicateSanctionsProviderSale.consumer());
        emit log_named_address(_prefix(2, "predicate manager"), predicateSanctionsProviderSale.getPredicateManager());
        emit log_named_string(_prefix(2, "policy"), predicateSanctionsProviderSale.getPolicy());
        emit log("");
    }

    function _stakingRegistry() internal {
        string memory json = _loadJson();

        StakingRegistry stakingRegistry = StakingRegistry(vm.parseJsonAddress(json, ".stakingRegistry"));

        emit log("=== Staking Registry Configuration ===");

        emit log_named_address(_prefix(1, "staking registry"), address(stakingRegistry));
        emit log_named_address(_prefix(2, "staking asset"), address(stakingRegistry.STAKING_ASSET()));
        emit log_named_address(_prefix(2, "pull split factory"), address(stakingRegistry.PULL_SPLIT_FACTORY()));
        emit log_named_address(_prefix(2, "rollup registry"), address(stakingRegistry.ROLLUP_REGISTRY()));
        emit log("");
    }

    function _splitsContracts() internal {
        string memory json = _loadJson();

        emit log("=== Splits Contracts Configuration ===");

        if (block.chainid == 31337) {
            emit log_named_address(_prefix(1, "splits warehouse"), vm.parseJsonAddress(json, ".splitsWarehouse"));
        }
        emit log_named_address(_prefix(1, "pull split factory"), vm.parseJsonAddress(json, ".pullSplitFactory"));
        emit log("");
    }

    function _auction() internal {
        string memory json = _loadJson();

        emit log("=== Auction/TWAP Configuration ===");

        // Virtual Aztec Token
        VirtualAztecToken vToken = VirtualAztecToken(vm.parseJsonAddress(json, ".virtualAztecToken"));
        emit log_named_address(_prefix(1, "virtual aztec token"), address(vToken));
        emit log_named_address(_prefix(2, "owner"), Ownable(address(vToken)).owner());
        emit log_named_string(_prefix(2, "name"), vToken.name());
        emit log_named_string(_prefix(2, "symbol"), vToken.symbol());
        emit log_named_address(_prefix(2, "foundation address"), vToken.FOUNDATION_ADDRESS());
        emit log_named_address(_prefix(2, "underlying token"), address(vToken.UNDERLYING_TOKEN_ADDRESS()));
        emit log_named_address(_prefix(2, "ATP factory"), address(vToken.ATP_FACTORY()));
        emit log_named_address(_prefix(2, "auction address"), address(vToken.auctionAddress()));
        emit log_named_address(_prefix(2, "strategy address"), vToken.strategyAddress());
        emit log_named_decimal_uint(_prefix(2, "total supply"), vToken.totalSupply(), 18);
        Aztec asset = Aztec(vm.parseJsonAddress(json, ".stakingAssetAddress"));
        emit log_named_decimal_uint(_prefix(2, "underlying balance"), asset.balanceOf(address(vToken)), 18);
        emit log("");

        // ATP Factory and Registry (Auction)
        ATPFactoryNonces atpFactoryAuction = ATPFactoryNonces(vm.parseJsonAddress(json, ".atpFactoryAuction"));
        ATPRegistry atpRegistryAuction = ATPRegistry(vm.parseJsonAddress(json, ".atpRegistryAuction"));

        emit log_named_address(_prefix(1, "ATP factory (auction)"), address(atpFactoryAuction));
        emit log_named_address(_prefix(2, "owner"), Ownable(address(atpFactoryAuction)).owner());
        emit log_named_address(_prefix(2, "pending owner"), Ownable2Step(address(atpFactoryAuction)).pendingOwner());
        emit log_named_address(_prefix(2, "token"), address(atpFactoryAuction.getToken()));
        emit log_named_address(_prefix(2, "registry"), address(atpFactoryAuction.getRegistry()));
        emit log_named_string(
            _prefix(2, "virtual token is minter"), atpFactoryAuction.minter(address(vToken)) ? "true" : "false"
        );
        emit log("");

        emit log_named_address(_prefix(1, "ATP registry (auction)"), address(atpRegistryAuction));
        emit log_named_address(_prefix(2, "owner"), Ownable(address(atpRegistryAuction)).owner());
        emit log_named_address(_prefix(2, "pending owner"), Ownable2Step(address(atpRegistryAuction)).pendingOwner());
        emit log(_prefix(2, "global lock params"));
        emit log_named_uint(_prefix(3, "cliff duration"), atpRegistryAuction.getGlobalLockParams().cliffDuration);
        emit log_named_uint(_prefix(3, "lock duration"), atpRegistryAuction.getGlobalLockParams().lockDuration);
        emit log_named_uint(_prefix(2, "execute allowed at"), atpRegistryAuction.getExecuteAllowedAt());
        emit log_named_uint(_prefix(2, "unlock start time"), atpRegistryAuction.getUnlockStartTime());
        emit log_named_uint(
            _prefix(2, "next staker version"), StakerVersion.unwrap(atpRegistryAuction.getNextStakerVersion())
        );

        emit log(_prefix(2, "staker implementations"));
        address stakerV1Auction = atpRegistryAuction.getStakerImplementation(StakerVersion.wrap(1));
        emit log_named_address(_prefix(3, "version 1 (withdrawable & claimable)"), stakerV1Auction);

        ATPWithdrawableAndClaimableStaker stakerAuction = ATPWithdrawableAndClaimableStaker(stakerV1Auction);
        emit log_named_uint(_prefix(4, "withdrawal timestamp"), stakerAuction.WITHDRAWAL_TIMESTAMP());
        emit log("");

        // Auction
        IContinuousClearingAuction auction = IContinuousClearingAuction(vm.parseJsonAddress(json, ".twapAuction"));
        emit log_named_address(_prefix(1, "continuous clearing auction"), address(auction));
        emit log_named_address(_prefix(2, "token"), address(auction.token()));
        emit log_named_address(_prefix(2, "currency"), Currency.unwrap(auction.currency()));
        emit log_named_address(_prefix(2, "tokens recipient"), auction.tokensRecipient());
        emit log_named_address(_prefix(2, "funds recipient"), auction.fundsRecipient());
        emit log_named_uint(_prefix(2, "start block"), auction.startBlock());
        emit log_named_uint(_prefix(2, "end block"), auction.endBlock());
        emit log_named_uint(_prefix(2, "claim block"), auction.claimBlock());
        {
            uint256 usdPerEth = 3500e18;
            uint256 tickSpacing = auction.tickSpacing();
            uint256 floorPrice = auction.floorPrice();

            uint256 Q96 = 2 ** 96;

            emit log_named_decimal_uint(_prefix(2, "pricing with eth value at (usd/ether)"), usdPerEth, 18);

            uint256 floorPriceUsd = floorPrice * usdPerEth / Q96;
            uint256 tickSpacingUsd = tickSpacing * usdPerEth / Q96;

            emit log_named_uint(_prefix(3, "floor price in Q96 (ether/aztec)"), floorPrice);
            emit log_named_decimal_uint(_prefix(3, "floor price (usd/aztec)"), floorPriceUsd, 18);

            emit log_named_uint(_prefix(3, "tick spacing in Q96 (ether/aztec)"), tickSpacing);
            emit log_named_decimal_uint(_prefix(3, "tick spacing (usd/aztec)"), tickSpacingUsd, 18);
        }
        emit log_named_address(_prefix(2, "validation hook"), address(auction.validationHook()));
        emit log_named_decimal_uint(_prefix(2, "token balance"), vToken.balanceOf(address(auction)), 18);
        emit log("");

        // Auction Hook
        AztecAuctionHook auctionHook = AztecAuctionHook(vm.parseJsonAddress(json, ".auctionHook"));
        emit log_named_address(_prefix(1, "auction hook"), address(auctionHook));
        emit log_named_address(_prefix(2, "owner"), Ownable(address(auctionHook)).owner());
        emit log_named_address(_prefix(2, "soulbound token"), address(auctionHook.SOULBOUND()));
        emit log_named_address(_prefix(2, "auction"), address(auctionHook.auction()));
        emit log_named_uint(_prefix(2, "contributor period end"), auctionHook.CONTRIBUTOR_PERIOD_END_BLOCK());
        emit log("");

        // Predicate Auction Screening Provider
        PredicateProvider predicateAuctionProvider =
            PredicateProvider(vm.parseJsonAddress(json, ".predicateAuctionScreeningProvider"));
        emit log_named_address(_prefix(1, "predicate auction screening"), address(predicateAuctionProvider));
        emit log_named_address(_prefix(2, "owner"), Ownable(address(predicateAuctionProvider)).owner());
        emit log_named_address(_prefix(2, "consumer"), predicateAuctionProvider.consumer());
        emit log_named_address(_prefix(2, "predicate manager"), predicateAuctionProvider.getPredicateManager());
        emit log_named_string(_prefix(2, "policy"), predicateAuctionProvider.getPolicy());
        emit log("");

        // Token Launcher and Strategy
        emit log_named_address(_prefix(1, "token launcher"), vm.parseJsonAddress(json, ".tokenLauncher"));
        emit log_named_address(_prefix(1, "permit2"), vm.parseJsonAddress(json, ".permit2"));
        emit log_named_address(_prefix(1, "virtual LBP factory"), vm.parseJsonAddress(json, ".virtualLBPFactory"));
        emit log("");

        IVirtualLBPStrategyBasic strategy = IVirtualLBPStrategyBasic(payable(vm.parseJsonAddress(json, ".virtualLBP")));
        emit log_named_address(_prefix(1, "virtual LBP strategy"), address(strategy));
        emit log_named_address(_prefix(2, "governance"), address(strategy.GOVERNANCE()));
        emit log_named_address(_prefix(2, "operator"), strategy.operator());
        emit log_named_address(_prefix(2, "position recipient"), strategy.positionRecipient());
        emit log_named_address(_prefix(2, "position manager"), address(strategy.positionManager()));
        emit log_named_uint(_prefix(2, "migration block"), strategy.migrationBlock());
        emit log_named_uint(_prefix(2, "sweep block"), strategy.sweepBlock());
        emit log_named_uint(_prefix(2, "pool LP fee"), strategy.poolLPFee());
        emit log_named_uint(_prefix(2, "pool tick spacing"), uint256(int256(strategy.poolTickSpacing())));
        emit log_named_decimal_uint(_prefix(2, "virtual token balance"), vToken.balanceOf(address(strategy)), 18);
        emit log("");

        // Date Gated Relayer
        GovernanceAcceleratedLock dgr = GovernanceAcceleratedLock(vm.parseJsonAddress(json, ".twapDateGatedRelayer"));
        emit log_named_address(_prefix(1, "date gated relayer"), address(dgr));
        emit log_named_address(_prefix(2, "governance"), Ownable(address(dgr)).owner());
        emit log_named_uint(_prefix(2, "start time"), dgr.START_TIME());
        emit log("");

        // Auction Factory
        emit log_named_address(_prefix(1, "auction factory"), vm.parseJsonAddress(json, ".auctionFactory"));
        emit log_named_uint(_prefix(1, "start block"), vm.parseJsonUint(json, ".startBlock"));
        emit log("");
    }

    function _foundationPayload() internal {
        string memory json = _loadJson();

        FoundationPayload foundationPayload = FoundationPayload(vm.parseJsonAddress(json, ".foundationPayloadAddress"));

        emit log("=== Foundation Payload Configuration ===");

        emit log_named_address(_prefix(1, "foundation payload"), address(foundationPayload));
        emit log_named_string(_prefix(2, "is executed"), foundationPayload.isSet() ? "true" : "false");
        emit log_named_address(_prefix(2, "owner"), Ownable(address(foundationPayload)).owner());

        FoundationPayloadConfig memory config = foundationPayload.getConfig();

        emit log(_prefix(2, "funder"));
        emit log_named_address(_prefix(3, "address"), config.funder);
        emit log_named_decimal_uint(_prefix(3, "mint to funder"), config.foundationFunding.mintToFunder, 18);
        emit log("");

        emit log(_prefix(2, "aztec configuration"));
        emit log_named_address(_prefix(3, "token"), config.aztec.token);
        emit log_named_address(_prefix(3, "governance"), config.aztec.governance);
        emit log_named_address(_prefix(3, "reward distributor"), config.aztec.rewardDistributor);
        emit log_named_address(_prefix(3, "flush rewarder"), config.aztec.flushRewarder);
        emit log_named_address(_prefix(3, "coin issuer"), config.aztec.coinIssuer);
        emit log_named_address(_prefix(3, "protocol treasury"), config.aztec.protocolTreasury);
        emit log_named_decimal_uint(
            _prefix(3, "tokens to reward distributor"), config.aztec.tokensToRewardDistributor, 18
        );
        emit log_named_decimal_uint(_prefix(3, "tokens to flush rewarder"), config.aztec.tokensToFlushRewarder, 18);
        emit log("");

        emit log(_prefix(2, "genesis sale configuration"));
        emit log_named_address(_prefix(3, "genesis sequencer sale"), config.genesisSale.genesisSequencerSale);
        emit log_named_decimal_uint(
            _prefix(3, "tokens to genesis sale"), config.genesisSale.tokensToGenesisSequencerSale, 18
        );
        emit log("");

        emit log(_prefix(2, "twap configuration"));
        emit log_named_address(_prefix(3, "virtual token"), config.twap.virtualToken);
        emit log_named_decimal_uint(_prefix(3, "tokens to virtual token"), config.twap.tokensToVirtualToken, 18);
        emit log_named_address(_prefix(3, "permit2"), config.twap.permit2);
        emit log_named_address(_prefix(3, "token launcher"), config.twap.tokenLauncher);
        emit log_named_bytes32(_prefix(3, "generated salt"), config.twap.generatedSalt);
        emit log_named_address(_prefix(3, "auction"), config.twap.auction);
        emit log("");

        emit log(_prefix(2, "governance payload configuration"));
        emit log_named_address(_prefix(3, "ATP registry"), config.govPayload.atpRegistry);
        emit log_named_address(_prefix(3, "date gated relayer short"), config.govPayload.dateGatedRelayerShort);
        emit log("");

        emit log(_prefix(2, "protocol treasury configuration"));
        emit log_named_decimal_uint(
            _prefix(3, "tokens for treasury"), config.protocolTreasuryConfig.tokensForTreasury, 18
        );
        emit log("");
    }

    function _dirstribution() internal {
        string memory json = _loadJson();
        Aztec asset = Aztec(vm.parseJsonAddress(json, ".stakingAssetAddress"));
        IERC20 vAsset = IERC20(vm.parseJsonAddress(json, ".virtualAztecToken"));

        emit log("==========================");
        emit log("=== TOKEN DISTRIBUTION ===");
        emit log("==========================");

        emit log_named_address(_prefix(1, "distribution for"), address(asset));
        emit log_named_string(_prefix(1, "name"), asset.name());
        emit log_named_decimal_uint(_prefix(1, "supply"), asset.totalSupply(), 18);

        uint256 genesisSaleAmount = asset.balanceOf(vm.parseJsonAddress(json, ".genesisSequencerSale"));
        uint256 auctionAmount = vAsset.balanceOf(vm.parseJsonAddress(json, ".twapAuction"));
        uint256 poolAmount = vAsset.balanceOf(vm.parseJsonAddress(json, ".virtualLBP"));
        uint256 tokenSale = genesisSaleAmount + auctionAmount + poolAmount;

        emit log_named_decimal_uint(_prefix(2, "token sale + bilateral"), tokenSale + 252_500_000e18, 18);
        emit log_named_decimal_uint(_prefix(2, "token sale"), tokenSale, 18);
        emit log_named_decimal_uint(_prefix(3, "genesis sale"), genesisSaleAmount, 18);
        emit log_named_decimal_uint(_prefix(3, "open auction"), auctionAmount, 18);
        emit log_named_decimal_uint(_prefix(3, "Liquidity pool"), poolAmount, 18);

        uint256 futureIncentives = asset.balanceOf(vm.parseJsonAddress(json, ".protocolTreasuryAddress"));
        emit log_named_decimal_uint(_prefix(2, "future incentives"), futureIncentives, 18);

        uint256 rewardDistributorAmount = asset.balanceOf(vm.parseJsonAddress(json, ".rewardDistributorAddress"));
        uint256 flushRewarderAmount = asset.balanceOf(vm.parseJsonAddress(json, ".flushRewarderAddress"));
        uint256 rewards = rewardDistributorAmount + flushRewarderAmount;
        emit log_named_decimal_uint(_prefix(2, "Y1 rewards"), rewards, 18);
        emit log_named_decimal_uint(_prefix(3, "reward distributor"), rewardDistributorAmount, 18);
        emit log_named_decimal_uint(_prefix(3, "flush rewarder"), flushRewarderAmount, 18);

        uint256 foundationAmount = asset.balanceOf(vm.parseJsonAddress(json, ".tokenOwnerAddress"));
        uint256 bilateralAmount = 252_500_000e18;
        uint256 grantAmount = 1_111_000_000e18;
        uint256 rawFoundationAmount = 1_211_500_000e18;
        uint256 expectedFoundationAmount = bilateralAmount + grantAmount + rawFoundationAmount;
        emit log_named_decimal_uint(_prefix(2, "total foundation foundation"), foundationAmount, 18);
        emit log_named_decimal_uint(_prefix(3, "bilateral sale"), bilateralAmount, 18);
        emit log_named_decimal_uint(_prefix(3, "grants"), grantAmount, 18);
        emit log_named_decimal_uint(_prefix(3, "foundation"), rawFoundationAmount, 18);

        assertEq(foundationAmount, expectedFoundationAmount, "invalid foundation amount");

        emit log("==========================");
    }

    function _prefix(uint256 level, string memory value) internal pure returns (string memory) {
        uint256 prefixSize = level * 4;
        string memory output = value;
        for (uint256 i = 0; i < prefixSize; i++) {
            output = string.concat(" ", output);
        }

        uint256 l = bytes(output).length;
        for (uint256 i = l; i < INDENTION; i++) {
            output = string.concat(output, " ");
        }

        return output;
    }
}
