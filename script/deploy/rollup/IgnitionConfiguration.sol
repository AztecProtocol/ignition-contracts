// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

import {
    ProtocolTreasuryConfiguration,
    CoinIssuerConfiguration,
    GseConfiguration,
    GovernanceProposerConfiguration,
    FlushRewardConfiguration
} from "./Configuration.sol";
import {IRewardDistributor} from "@aztec/governance/interfaces/IRewardDistributor.sol";
import {IBoosterCore} from "@aztec/core/reward-boost/RewardBooster.sol";
import {SlasherFlavor} from "@aztec/core/interfaces/ISlasher.sol";
import {EthValue} from "@aztec/core/libraries/rollup/FeeLib.sol";
import {GenesisState} from "@aztec/core/interfaces/IRollup.sol";
import {RollupConfigInput} from "@aztec/core/interfaces/IRollup.sol";
import {Timestamp} from "@aztec/shared/libraries/TimeMath.sol";
import {
    Configuration as GovernanceConfiguration,
    ProposeWithLockConfiguration
} from "@aztec/governance/interfaces/IGovernance.sol";
import {RewardBoostConfig} from "@aztec/core/reward-boost/RewardBooster.sol";
import {StakingQueueConfig} from "@aztec/core/libraries/compressed-data/StakingQueueConfig.sol";
import {RewardConfig} from "@aztec/core/libraries/rollup/RewardLib.sol";
import {Bps} from "@aztec/core/libraries/rollup/RewardLib.sol";
import {IAztecConfiguration} from "./Configuration.sol";
import {IgnitionSharedDates} from "../IgnitionSharedDates.sol";

// We are going to setup the configuration that is not addresses of other contracts
contract IgnitionConfiguration is IAztecConfiguration {
    function getProtocolTreasuryConfiguration() public view returns (ProtocolTreasuryConfiguration memory) {
        return ProtocolTreasuryConfiguration({gatedUntil: IgnitionSharedDates.START_TIMESTAMP + 365 days});
    }

    // Time for when ignition starts + 90 days
    function getEarliestRewardsClaimableTimestamp() public view returns (Timestamp) {
        return Timestamp.wrap(IgnitionSharedDates.START_TIMESTAMP + 90 days);
    }

    // coinIssuer:
    //   # the coin issuer owns the token, and the only contract able to mint.
    //   # Governance is able to call mint on the coin issuer, which accrues an amount that
    //   # may be minted at a particular rate
    //   rate: 20% # max annual inflation
    function getCoinIssuerConfiguration() public pure returns (CoinIssuerConfiguration memory) {
        return CoinIssuerConfiguration({coinIssuerRate: 0.2e18});
    }

    // gse:
    //   # The deposit amount for a validator
    //   activationThreshold: 200_000e18
    //   # The minimum stake for a validator.
    //   ejectionThreshold: 100_000e18
    function getGseConfiguration() public pure returns (GseConfiguration memory) {
        return GseConfiguration({activationThreshold: 200_000e18, ejectionThreshold: 100_000e18});
    }

    // governanceProposer:
    //     # Governance proposing quorum (defaults to roundSize/2 + 1)
    //     governanceProposerQuorum: 600
    //     # Governance proposing round size
    //     governanceProposerRoundSize: 1000
    function getGovernanceProposerConfiguration() public pure returns (GovernanceProposerConfiguration memory) {
        return GovernanceProposerConfiguration({quorum: 600, roundSize: 1000});
    }

    // governance:
    //   proposeConfig:
    //     lockDelay: 90 * 24 * 60 * 60 # 90 days, may change at alpha
    //     lockAmount: 258_750_000e18 # 2.5% * 10.35B of initial supply
    //  votingDelay: 3 * 24 * 60 * 60 # 3 days
    //  votingDuration: 7 * 24 * 60 * 60 # 7 days
    //  executionDelay: 7 * 24 * 60 * 60 # 7 days
    //  gracePeriod: 7 * 24 * 60 * 60 # 7 days
    //  quorum: 20% # may change at alpha
    //  # 2/3 must vote yes
    //  requiredYeaMargin: 33%
    //  # 1000 nodes worth of voting power must be deposited
    //  minimumVotes: 1000 * 200_000e18
    function getGovernanceConfiguration() public pure returns (GovernanceConfiguration memory) {
        return GovernanceConfiguration({
            proposeConfig: ProposeWithLockConfiguration({lockDelay: Timestamp.wrap(90 days), lockAmount: 258_750_000e18}),
            votingDelay: Timestamp.wrap(3 days),
            votingDuration: Timestamp.wrap(7 days),
            executionDelay: Timestamp.wrap(7 days),
            gracePeriod: Timestamp.wrap(7 days),
            quorum: 0.2e18,
            requiredYeaMargin: 0.33e18,
            minimumVotes: 500 * 200_000e18
        });
    }

    function getGenesisState() public pure returns (GenesisState memory) {
        // @todo - need to be updated
        return GenesisState({
            vkTreeRoot: bytes32(0x229eadb7c540c82204b5373633d3c25557f8264ad8fca760660fe853e5275e39),
            protocolContractTreeRoot: bytes32(0x12e9aa367b065eff3e48912b8cae62209970117d34a8c9ef1e9e4116e41bc8d6),
            genesisArchiveRoot: bytes32(0x1f9c798be7975bb34c3e605a4c92c75796eae7b9a08644bc9a6a55354ed470be)
        });
    }

    // rewardConfig:
    //   sequencerBps: 7000 # sequencer gets 70% of block rewards
    //   blockReward: 400e18 # block reward is 400 $AZTEC
    function getRewardConfiguration(IRewardDistributor _rewardDistributor) public pure returns (RewardConfig memory) {
        return RewardConfig({
            rewardDistributor: _rewardDistributor,
            sequencerBps: Bps.wrap(7000),
            booster: IBoosterCore(address(0)),
            blockReward: 400e18
        });
    }

    function getRewardBoostConfiguration() public pure returns (RewardBoostConfig memory) {
        return RewardBoostConfig({increment: 125_000, maxScore: 15_000_000, a: 1000, minimum: 100_000, k: 1_000_000});
    }

    function getStakingQueueConfiguration() public pure returns (StakingQueueConfig memory) {
        return StakingQueueConfig({
            bootstrapValidatorSetSize: 500,
            bootstrapFlushSize: 500,
            normalFlushSizeMin: 1,
            normalFlushSizeQuotient: 2048,
            maxQueueFlushSize: 8
        });
    }

    function getRollupConfiguration(IRewardDistributor _rewardDistributor)
        public
        view
        returns (RollupConfigInput memory)
    {
        return RollupConfigInput({
            aztecSlotDuration: 72,
            aztecEpochDuration: 32,
            targetCommitteeSize: 24,
            lagInEpochs: 2,
            aztecProofSubmissionEpochs: 1,
            localEjectionThreshold: 196_000e18,
            slashingQuorum: 65,
            slashingRoundSize: 128,
            slashingLifetimeInRounds: 34,
            slashingExecutionDelayInRounds: 28,
            slashAmounts: [uint256(2000e18), uint256(2000e18), uint256(2000e18)],
            slashingOffsetInRounds: 2,
            slasherFlavor: SlasherFlavor.TALLY,
            slashingVetoer: 0xBbB4aF368d02827945748b28CD4b2D42e4A37480,
            slashingDisableDuration: 3 days,
            manaTarget: 0,
            exitDelaySeconds: 4 days,
            version: 0,
            provingCostPerMana: EthValue.wrap(0),
            rewardConfig: getRewardConfiguration(_rewardDistributor),
            rewardBoostConfig: getRewardBoostConfiguration(),
            stakingQueueConfig: getStakingQueueConfiguration(),
            earliestRewardsClaimableTimestamp: getEarliestRewardsClaimableTimestamp()
        });
    }

    // flushRewarder:
    //   rewardPerInsertion: 100e18
    //   initialFundingAmount: 1000000e18 # pre-fund enough for 10,000 flushes during deployment
    function getFlushRewardConfiguration() public pure returns (FlushRewardConfiguration memory) {
        return FlushRewardConfiguration({rewardPerInsertion: 100e18, initialFundingAmount: 1_000_000e18});
    }

    function getRewardDistributorFunding() public pure returns (uint256) {
        return 249_000_000e18;
    }
}
