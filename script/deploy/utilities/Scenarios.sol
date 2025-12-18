// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {TestBase} from "@aztec-test/base/Base.sol";

import {GenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";
import {IgnitionParticipantSoulbound} from "src/soulbound/IgnitionParticipantSoulbound.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {NCATP} from "@atp/atps/noclaim/NCATP.sol";
import {LATP} from "@atp/atps/linear/LATP.sol";
import {Lock} from "@atp/libraries/LockLib.sol";
import {IATPNonWithdrawableStaker} from "src/staking/ATPNonWithdrawableStaker.sol";

import {IInstance} from "@aztec/core/interfaces/IInstance.sol";
import {TestERC20} from "@aztec/mock/TestERC20.sol";
import {IRegistry, StakerVersion} from "@atp/Registry.sol";
import {VmSafe} from "lib/forge-std/src/Vm.sol";
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";
import {ATPWithdrawableAndClaimableStaker} from "src/staking/ATPWithdrawableAndClaimableStaker.sol";
import {IWhitelistProvider} from "src/soulbound/providers/IWhitelistProvider.sol";
import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";
import {GovernanceProposer} from "@aztec/governance/proposer/GovernanceProposer.sol";
import {VirtualAztecToken} from "src/uniswap-periphery/VirtualAztecToken.sol";
import {IVirtualLBPStrategyBasic} from "src/uniswap-periphery/IVirtualLBPStrategyBasic.sol";

import {IATPFactory} from "@atp/ATPFactory.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {IRegistry as IRollupRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";
import {StakingRegistry, IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {Governance} from "@aztec/governance/Governance.sol";
import {
    Configuration as GovernanceConfiguration,
    Proposal,
    IGovernance
} from "@aztec/governance/interfaces/IGovernance.sol";
import {Timestamp, Slot, Epoch} from "@aztec/shared/libraries/TimeMath.sol";
import {DateGatedRelayer} from "@aztec/periphery/DateGatedRelayer.sol";
import {IPayload} from "@aztec/governance/interfaces/IPayload.sol";

import {StateLibrary} from "@v4c/libraries/StateLibrary.sol";
import {TickMath} from "@v4c/libraries/TickMath.sol";
import {FullMath} from "@v4c/libraries/FullMath.sol";
import {FixedPoint96} from "@v4c/libraries/FixedPoint96.sol";
import {IPoolManager} from "@v4c/interfaces/IPoolManager.sol";
import {PoolKey} from "@v4c/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@v4c/types/PoolId.sol";
import {PositionInfo} from "@v4p/libraries/PositionInfoLibrary.sol";
import {Currency} from "@v4c/types/Currency.sol";
import {IHooks} from "@v4c/interfaces/IHooks.sol";
import {IV4Router} from "@v4p/interfaces/IV4Router.sol";
import {Actions} from "@v4p/libraries/Actions.sol";
import {GovernanceAcceleratedLock} from "src/uniswap-periphery/GovernanceAcceleratedLock.sol";
import {GSEPayload} from "@aztec/governance/GSEPayload.sol";
import {IPositionManager} from "@v4p/interfaces/IPositionManager.sol";
import {FoundationWallets} from "../CollectiveDeploy.s.sol";
import {Payload90} from "../gov/Payload90.sol";
import {IRegistry as IATPRegistry} from "@atp/Registry.sol";
import {ProtocolTreasury} from "src/ProtocolTreasury.sol";
// Simple interface for the Universal Router

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}

uint256 constant GOV_PARTICIPANTS_COUNT = 20;

struct TwapScenario {
    // Contracts
    IgnitionParticipantSoulbound soul;
    VirtualAztecToken vToken;
    IInstance rollup;
    TestERC20 token;
    IContinuousClearingAuction auction;
    // Participants
    address stakeAmountTester;
    address lowAmountTester;
    address[GOV_PARTICIPANTS_COUNT] govParticipants;
    // Atps
    NCATP ncatp;
    LATP latp;
    NCATP[GOV_PARTICIPANTS_COUNT] govParticipantAtps;
}

contract Scenarios is TestBase {
    using StateLibrary for IPoolManager;

    FoundationWallets internal WALLETS;

    modifier snapshotted() {
        uint256 snapshotId = vm.snapshot();
        _;
        vm.revertTo(snapshotId);
    }

    function _loadJson() internal returns (string memory) {
        string memory chainId = vm.toString(block.chainid);
        string memory deploymentsDir = vm.envString("DEPLOYMENTS_DIR");
        if (!vm.exists(deploymentsDir)) {
            vm.createDir(deploymentsDir, true);
        }
        string memory inputPath = string.concat(deploymentsDir, "/collective-l1-deployment-", chainId, ".json");
        return vm.readFile(inputPath);
    }

    function sale() public snapshotted {
        // 1. Buy in the genesis sale
        // 2. Deposit into the rollup
        // 3. Claim when delay has passed

        emit log("================================");
        emit log("Scenario: sale");

        string memory json = _loadJson();

        address tester = makeAddr("tester");

        GenesisSequencerSale gss = GenesisSequencerSale(vm.parseJsonAddress(json, ".genesisSequencerSale"));
        IgnitionParticipantSoulbound soul = IgnitionParticipantSoulbound(vm.parseJsonAddress(json, ".soulboundToken"));
        IInstance rollup = IInstance(vm.parseJsonAddress(json, ".rollupAddress"));

        uint256 cost = gss.getPurchaseCostInEth();
        emit log_named_decimal_uint("cost", cost, 18);

        uint256 saleStartTime = gss.saleStartTime();

        vm.warp(saleStartTime);
        emit log_named_uint("Warped to", block.timestamp);

        if (!soul.hasGenesisSequencerToken(tester)) {
            emit log("Minting soulbound token");
            vm.deal(soul.owner(), 1 ether);
            vm.prank(soul.owner());
            soul.adminMint(tester, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, 0);
        }

        vm.mockCall(
            address(gss.addressScreeningProvider()),
            abi.encodeWithSelector(IWhitelistProvider.verify.selector, tester, ""),
            abi.encode(true)
        );

        emit log("Purchasing from genesis sale");
        vm.deal(tester, cost + 1 ether);
        vm.prank(tester);
        vm.recordLogs();
        gss.purchase{value: cost}(tester, "");

        VmSafe.Log[] memory logs = vm.getRecordedLogs();

        NCATP atp = NCATP(address(uint160(uint256(logs[logs.length - 1].topics[3]))));
        IRegistry registry = IRegistry(address(atp.getRegistry()));
        TestERC20 token = TestERC20(address(atp.getToken()));

        emit log_named_address("User", tester);
        emit log_named_address("Token", address(token));
        emit log_named_address("ATP ", address(atp));
        emit log_named_address("Registry", address(registry));
        emit log_named_address("Staker", address(atp.getStaker()));
        emit log_named_decimal_uint("ATP balance", token.balanceOf(address(atp)), 18);
        emit log_named_decimal_uint("Beneficiary balance", token.balanceOf(tester), 18);

        // Upgrade the staker implementation
        ATPWithdrawableAndClaimableStaker staker = ATPWithdrawableAndClaimableStaker(address(atp.getStaker()));

        emit log("Upgrading staker implementation");

        vm.prank(tester);
        atp.upgradeStaker(StakerVersion.wrap(1));

        emit log("Updating staker operator");
        vm.prank(tester);
        atp.updateStakerOperator(tester);

        {
            emit log("Approving staker");
            uint256 activationThreshold = rollup.getActivationThreshold();
            vm.prank(tester);
            atp.approveStaker(activationThreshold);
        }

        emit log_named_uint("Queue length", rollup.getEntryQueueLength());

        {
            emit log("Staking");
            uint256 version = rollup.getVersion();

            vm.prank(tester);
            staker.stake(
                version,
                tester,
                BN254Lib.G1Point({x: 0, y: 0}),
                BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
                BN254Lib.G1Point({x: 0, y: 0}),
                true
            );
        }

        emit log_named_uint("Queue length", rollup.getEntryQueueLength());

        uint256 withdrawalTimestamp = staker.WITHDRAWAL_TIMESTAMP();
        vm.warp(withdrawalTimestamp + 1);
        emit log_named_uint("Warped to", block.timestamp);
        {
            emit log("Approving staker");
            uint256 atpBalance = token.balanceOf(address(atp));
            vm.prank(tester);
            atp.approveStaker(atpBalance);

            emit log("Withdrawing tokens to beneficiary");
            vm.prank(tester);
            staker.withdrawAllTokensToBeneficiary();
        }

        emit log_named_decimal_uint("ATP balance", token.balanceOf(address(atp)), 18);
        emit log_named_decimal_uint("Beneficiary balance", token.balanceOf(tester), 18);

        emit log("================================");
    }

    function twap() public snapshotted {
        // Make bids and see that it is possible to get the tokens and stake etc.
        // Be liberal with the logging such that it is simple to follow along and understand this.

        emit log("================================");
        emit log("Scenario: auction");

        string memory json = _loadJson();

        TwapScenario memory $;
        $.stakeAmountTester = makeAddr("stakeAmountTester");
        $.lowAmountTester = makeAddr("lowAmountTester");
        $.auction = IContinuousClearingAuction(vm.parseJsonAddress(json, ".twapAuction"));
        $.soul = IgnitionParticipantSoulbound(vm.parseJsonAddress(json, ".soulboundToken"));
        $.vToken = VirtualAztecToken(vm.parseJsonAddress(json, ".virtualAztecToken"));
        $.rollup = IInstance(vm.parseJsonAddress(json, ".rollupAddress"));
        $.token = TestERC20(vm.parseJsonAddress(json, ".stakingAssetAddress"));

        vm.label($.stakeAmountTester, "stakeAmountTester");
        vm.label($.lowAmountTester, "lowAmountTester");
        vm.label(address($.auction), "auction");
        vm.label(address($.soul), "soul");
        vm.label(address($.vToken), "vToken");
        vm.label(address($.rollup), "rollup");
        vm.label(address($.token), "token");

        if (!$.soul.hasGenesisSequencerToken($.stakeAmountTester)) {
            emit log("Minting soulbound token");
            vm.deal($.soul.owner(), 1 ether);
            vm.prank($.soul.owner());
            $.soul.adminMint($.stakeAmountTester, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, 0);
        }

        if (!$.soul.hasContributorToken($.lowAmountTester)) {
            emit log("Minting contributor soulbound token");
            vm.deal($.soul.owner(), 1 ether);
            vm.prank($.soul.owner());
            $.soul.adminMint($.lowAmountTester, IIgnitionParticipantSoulbound.TokenId.CONTRIBUTOR, 1);
        }

        {
            uint256 startBlock = $.auction.startBlock();

            emit log_named_uint("Start block  ", startBlock);
            emit log_named_uint("Current block", block.number);

            if (block.number < startBlock) {
                emit log("Advancing block to start block");
                vm.roll(startBlock);
            }
        }

        uint256 stakeAmountBidId;
        uint256 lowAmountBidId;

        // Stake amount bid
        {
            uint256 floor = $.auction.floorPrice();
            uint256 tickSpacing = $.auction.tickSpacing();
            emit log_named_decimal_uint("Floor price", floor, 28);

            uint256 price = floor + tickSpacing;
            uint256 cost = $.rollup.getActivationThreshold() * price / (1 << 96);

            emit log_named_decimal_uint("Cost", cost, 18);

            vm.deal($.stakeAmountTester, cost + 1 ether);

            uint128 amount = uint128(cost);

            vm.prank($.stakeAmountTester);
            stakeAmountBidId = $.auction.submitBid{value: amount}(price, amount, $.stakeAmountTester, "");
        }

        // Low amount bid - puchase halg of the stake amount
        {
            uint256 floor = $.auction.floorPrice();
            uint256 tickSpacing = $.auction.tickSpacing();
            emit log_named_decimal_uint("Floor price", floor, 28);

            uint256 price = floor + tickSpacing;
            uint256 cost = ($.rollup.getActivationThreshold() / 2 * price) / (1 << 96);

            emit log_named_decimal_uint("Cost", cost, 18);

            vm.deal($.lowAmountTester, cost + 1 ether);

            uint128 amount = uint128(cost);

            vm.prank($.lowAmountTester);
            lowAmountBidId = $.auction.submitBid{value: amount}(price, amount, $.lowAmountTester, "");
        }

        {
            uint256 claimBlock = $.auction.claimBlock();
            if (block.number < claimBlock) {
                emit log("Advancing block to claim block");
                vm.roll(claimBlock);
            }
        }

        {
            emit log("Exiting and claiming bid");

            vm.prank($.stakeAmountTester);
            $.auction.exitBid(stakeAmountBidId);

            vm.prank($.stakeAmountTester);
            $.auction.claimTokens(stakeAmountBidId);

            vm.prank($.lowAmountTester);
            $.auction.exitBid(lowAmountBidId);

            vm.prank($.lowAmountTester);
            $.auction.claimTokens(lowAmountBidId);
        }
        {
            emit log_named_decimal_uint("Stake amount tester balance ", $.token.balanceOf($.stakeAmountTester), 18);
            emit log_named_decimal_uint(
                "Stake amount Tester: VToken balance ", $.vToken.balanceOf($.stakeAmountTester), 18
            );
            emit log_named_decimal_uint(
                "Stake amount Tester: pending balance", $.vToken.pendingAtpBalance($.stakeAmountTester), 18
            );

            emit log_named_decimal_uint("Low amount tester balance ", $.token.balanceOf($.lowAmountTester), 18);
            emit log_named_decimal_uint("Low amount Tester: VToken balance ", $.vToken.balanceOf($.lowAmountTester), 18);
            emit log_named_decimal_uint(
                "Low amount Tester: pending balance", $.vToken.pendingAtpBalance($.lowAmountTester), 18
            );
        }

        {
            emit log("Stake amount tester: sweeping into ATP");
            vm.recordLogs();
            vm.prank($.stakeAmountTester);
            $.vToken.sweepIntoAtp();

            VmSafe.Log[] memory logs = vm.getRecordedLogs();

            $.ncatp = NCATP(address(uint160(uint256(logs[logs.length - 1].topics[2]))));

            emit log_named_address("Stake amount tester: NCATP", address($.ncatp));
        }

        {
            emit log("Low amount tester: sweeping into ATP");
            vm.recordLogs();
            vm.prank($.lowAmountTester);
            $.vToken.sweepIntoAtp();

            VmSafe.Log[] memory logs = vm.getRecordedLogs();

            $.latp = LATP(address(uint160(uint256(logs[logs.length - 1].topics[2]))));

            emit log_named_address("Low amount tester: LATP", address($.latp));
        }

        {
            // Upgrade the staker implementation
            ATPWithdrawableAndClaimableStaker staker = ATPWithdrawableAndClaimableStaker(address($.ncatp.getStaker()));
            emit log_named_address("Staker", address(staker));

            emit log("Stake amount tester: upgrading staker implementation");

            vm.prank($.stakeAmountTester);
            $.ncatp.upgradeStaker(StakerVersion.wrap(1));

            emit log("Updating staker operator");
            vm.prank($.stakeAmountTester);
            $.ncatp.updateStakerOperator($.stakeAmountTester);

            {
                emit log("Approving staker");
                uint256 activationThreshold = $.rollup.getActivationThreshold();
                vm.prank($.stakeAmountTester);
                $.ncatp.approveStaker(activationThreshold);
            }

            emit log_named_uint("Queue length", $.rollup.getEntryQueueLength());

            {
                emit log("Staking");
                uint256 version = $.rollup.getVersion();

                vm.prank($.stakeAmountTester);
                staker.stake(
                    version,
                    $.stakeAmountTester,
                    BN254Lib.G1Point({x: 0, y: 0}),
                    BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
                    BN254Lib.G1Point({x: 0, y: 0}),
                    true
                );
            }

            emit log_named_uint("Queue length", $.rollup.getEntryQueueLength());

            {
                emit log("Stake amount tester: Approving staker");
                uint256 atpBalance = $.token.balanceOf(address($.ncatp));
                vm.prank($.stakeAmountTester);
                $.ncatp.approveStaker(atpBalance);

                // withdraw all tokens should revert
                emit log(
                    "Stake amount tester: Withdrawing tokens to beneficiary - should reveert as not past withdrawal timestamp"
                );
                vm.expectRevert();
                vm.prank($.stakeAmountTester);
                staker.withdrawAllTokensToBeneficiary();

                // claim should revert as not past withdrawal timestamp
                emit log("Low amount tester: Claiming tokens - should do nothing as not past withdrawal timestamp");
                vm.expectRevert();
                vm.prank($.lowAmountTester);
                $.latp.claim();
            }

            uint256 withdrawalTimestamp = staker.WITHDRAWAL_TIMESTAMP();
            emit log_named_uint("Withdrawal timestamp", withdrawalTimestamp);
            vm.warp(withdrawalTimestamp + 1);
            emit log_named_uint("Warped to", block.timestamp);
            {
                emit log("Stake amount tester: Withdrawing tokens to beneficiary");
                vm.prank($.stakeAmountTester);
                staker.withdrawAllTokensToBeneficiary();
            }

            Lock memory globalLock = $.latp.getGlobalLock();
            emit log_named_uint("Global lock start time", globalLock.startTime);
            emit log_named_uint("Global lock end time", globalLock.endTime);
            emit log_named_uint("Global lock cliff", globalLock.cliff);
            emit log_named_uint("Global lock allocation", globalLock.allocation);
            emit log_named_uint("Current timestamp", block.timestamp);

            // By default, the claim period should unlock at 365 days after the end of the auction - with the posibility of gov decreasing to 90 days
            emit log_named_uint("Warping to global lock end time + 1", globalLock.endTime + 1);
            vm.warp(globalLock.endTime + 1);
            emit log_named_uint("Warped to", block.timestamp);
            {
                emit log("Low amount tester: Claiming tokens");
                vm.prank($.lowAmountTester);
                $.latp.claim();
            }

            emit log_named_decimal_uint("Stake amount tester: NCATP balance", $.token.balanceOf(address($.ncatp)), 18);
            emit log_named_decimal_uint(
                "Stake amount tester: Beneficiary balance", $.token.balanceOf($.stakeAmountTester), 18
            );
            emit log_named_decimal_uint("Low amount tester: LATP balance", $.token.balanceOf(address($.latp)), 18);
            emit log_named_decimal_uint(
                "Low amount tester: Beneficiary balance", $.token.balanceOf($.lowAmountTester), 18
            );
        }

        emit log("================================");
    }

    function tiny_gov() public snapshotted {
        emit log("================================");
        emit log("Scenario: tiny gov");
        emit log("This scenario can be used after the signalling is done to submit the payload and show execution");

        string memory json = _loadJson();

        TwapScenario memory $;
        $.stakeAmountTester = makeAddr("stakeAmountTester");
        $.lowAmountTester = makeAddr("lowAmountTester");
        $.auction = IContinuousClearingAuction(vm.parseJsonAddress(json, ".twapAuction"));
        $.soul = IgnitionParticipantSoulbound(vm.parseJsonAddress(json, ".soulboundToken"));
        $.vToken = VirtualAztecToken(vm.parseJsonAddress(json, ".virtualAztecToken"));
        $.rollup = IInstance(vm.parseJsonAddress(json, ".rollupAddress"));
        $.token = TestERC20(vm.parseJsonAddress(json, ".stakingAssetAddress"));

        GovernanceProposer proposer = GovernanceProposer(vm.parseJsonAddress(json, ".governanceProposerAddress"));
        Governance governance = Governance(vm.parseJsonAddress(json, ".governanceAddress"));

        Slot slot =
            $.rollup.getCurrentSlot() + Slot.wrap(Slot.unwrap($.rollup.getCurrentSlot()) % proposer.ROUND_SIZE());
        Timestamp timestamp = $.rollup.getTimestampForSlot(slot);

        vm.warp(Timestamp.unwrap(timestamp));

        uint256 round = proposer.getCurrentRound();

        emit log_named_uint("Round", round);

        proposer.submitRoundWinner(round - 1);

        uint256 proposalId = governance.proposalCount() - 1;

        GovernanceConfiguration memory govConfig = governance.getConfiguration();

        emit log_named_uint("Proposal ID", proposalId);
        emit log_named_address("GSEPayload", address(governance.getProposal(proposalId).payload));
        emit log_named_address(
            "Payload   ", address(GSEPayload(address(governance.getProposal(proposalId).payload)).getOriginalPayload())
        );
    }

    function gov() public snapshotted {
        emit log("================================");
        emit log("Scenario: gov");

        string memory json = _loadJson();

        // We add an attester and use it to signal to pass a gov proposal
        address attester = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

        TempValues memory t;
        t.treasury = vm.parseJsonAddress(json, ".protocolTreasuryAddress");
        WALLETS.twapTokenRecipient = vm.parseJsonAddress(json, ".twapTokenRecipientAddress");
        WALLETS.auctionOperator = vm.parseJsonAddress(json, ".auctionOperatorAddress");

        TwapScenario memory $;
        $.stakeAmountTester = makeAddr("stakeAmountTester");
        $.lowAmountTester = makeAddr("lowAmountTester");
        $.auction = IContinuousClearingAuction(vm.parseJsonAddress(json, ".twapAuction"));
        $.soul = IgnitionParticipantSoulbound(vm.parseJsonAddress(json, ".soulboundToken"));
        $.vToken = VirtualAztecToken(vm.parseJsonAddress(json, ".virtualAztecToken"));
        $.rollup = IInstance(vm.parseJsonAddress(json, ".rollupAddress"));
        $.token = TestERC20(vm.parseJsonAddress(json, ".stakingAssetAddress"));

        vm.label(address($.auction), "auction");
        vm.label(address($.soul), "soul");
        vm.label(address($.vToken), "vToken");
        vm.label(address($.rollup), "rollup");
        vm.label(address($.token), "token");

        for (uint256 i = 0; i < GOV_PARTICIPANTS_COUNT; i++) {
            $.govParticipants[i] = makeAddr(string.concat("govParticipant", vm.toString(i)));
        }

        {
            if (!$.soul.hasGenesisSequencerToken($.stakeAmountTester)) {
                emit log("Minting stake amount tester soulbound token");
                vm.deal($.soul.owner(), 1 ether);
                vm.prank($.soul.owner());
                $.soul.adminMint($.stakeAmountTester, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, 420);
            }

            if (!$.soul.hasContributorToken($.lowAmountTester)) {
                emit log("Minting low amount tester soulbound token");
                vm.deal($.soul.owner(), 1 ether);
                vm.prank($.soul.owner());
                $.soul.adminMint($.lowAmountTester, IIgnitionParticipantSoulbound.TokenId.CONTRIBUTOR, 69);
            }

            for (uint256 i = 0; i < $.govParticipants.length; i++) {
                if (!$.soul.hasGenesisSequencerToken($.govParticipants[i])) {
                    emit log("Minting gov participant soulbound token");
                    vm.deal($.soul.owner(), 1 ether);
                    vm.prank($.soul.owner());
                    $.soul.adminMint(
                        $.govParticipants[i],
                        IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
                        uint256(keccak256(abi.encode(uint256(i + 2))))
                    );
                }
            }

            for (uint256 i = 0; i < $.govParticipants.length; i++) {
                if (!$.soul.hasGenesisSequencerToken($.govParticipants[i])) {
                    emit log("Minting gov participant soulbound token");
                    vm.deal($.soul.owner(), 1 ether);
                    vm.prank($.soul.owner());
                    $.soul.adminMint(
                        $.govParticipants[i], IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, 2 + i
                    );
                }
            }

            {
                uint256 startBlock = $.auction.startBlock();

                emit log_named_uint("Start block  ", startBlock);
                emit log_named_uint("Current block", block.number);

                if (block.number < startBlock) {
                    emit log("Advancing block to start block");
                    vm.roll(startBlock);
                }
            }

            uint256 stakeAmountBidId;
            uint256 lowAmountBidId;
            uint256[] memory govParticipantBidIds = new uint256[]($.govParticipants.length);

            {
                uint256 floor = $.auction.floorPrice();
                uint256 tickSpacing = $.auction.tickSpacing();
                emit log_named_decimal_uint("Floor price", floor, 28);

                uint256 price = floor + tickSpacing;
                uint256 cost = $.rollup.getActivationThreshold() * price / (1 << 96);

                emit log_named_decimal_uint("Cost", cost, 18);

                vm.deal($.stakeAmountTester, cost + 1 ether);

                uint128 amount = uint128(cost);

                vm.prank($.stakeAmountTester);
                stakeAmountBidId = $.auction.submitBid{value: amount}(price, amount, $.stakeAmountTester, "");
            }

            {
                uint256 floor = $.auction.floorPrice();
                uint256 tickSpacing = $.auction.tickSpacing();
                emit log_named_decimal_uint("Floor price", floor, 28);

                uint256 price = floor + tickSpacing;
                uint256 cost = ($.rollup.getActivationThreshold() / 2 * price) / (1 << 96);

                emit log_named_decimal_uint("Cost", cost, 18);

                vm.deal($.lowAmountTester, cost + 1 ether);

                uint128 amount = uint128(cost);

                vm.prank($.lowAmountTester);
                lowAmountBidId = $.auction.submitBid{value: amount}(price, amount, $.lowAmountTester, "");
            }

            {
                for (uint256 i = 0; i < $.govParticipants.length; i++) {
                    // Place max 250 eth bid for each gov participant
                    uint256 floor = $.auction.floorPrice();
                    uint256 tickSpacing = $.auction.tickSpacing();
                    emit log_named_decimal_uint("Floor price", floor, 28);

                    uint256 price = floor + tickSpacing;

                    uint256 cost;
                    // TODO(md): locally - maybe better to switch based on the CONFIGURATION instead
                    if (block.chainid == 1) {
                        cost = 250 ether;
                    } else {
                        cost = 0.00001 ether;
                    }

                    emit log_named_decimal_uint("Cost", cost, 18);

                    vm.deal($.govParticipants[i], cost + 1 ether);

                    uint128 amount = uint128(cost);

                    vm.prank($.govParticipants[i]);
                    govParticipantBidIds[i] =
                        $.auction.submitBid{value: amount}(price, amount, $.govParticipants[i], "");
                }
            }

            {
                uint256 claimBlock = $.auction.claimBlock();
                if (block.number < claimBlock) {
                    emit log("Advancing block to claim block");
                    vm.roll(claimBlock);
                }
            }

            {
                emit log("Exiting and claiming bid");

                vm.prank($.stakeAmountTester);
                $.auction.exitBid(stakeAmountBidId);

                vm.prank($.stakeAmountTester);
                $.auction.claimTokens(stakeAmountBidId);

                vm.prank($.lowAmountTester);
                $.auction.exitBid(lowAmountBidId);

                vm.prank($.lowAmountTester);
                $.auction.claimTokens(lowAmountBidId);

                for (uint256 i = 0; i < $.govParticipants.length; i++) {
                    vm.prank($.govParticipants[i]);
                    $.auction.exitBid(govParticipantBidIds[i]);

                    vm.prank($.govParticipants[i]);
                    $.auction.claimTokens(govParticipantBidIds[i]);
                }
            }

            {
                emit log("Stake amount tester: Sweeping into ATP");
                vm.recordLogs();
                vm.prank($.stakeAmountTester);
                $.vToken.sweepIntoAtp();

                VmSafe.Log[] memory logs = vm.getRecordedLogs();

                $.ncatp = NCATP(address(uint160(uint256(logs[logs.length - 1].topics[2]))));

                emit log_named_address("Stake amount: NCATP", address($.ncatp));
            }

            {
                emit log("Low amount tester: Sweeping into ATP");
                vm.recordLogs();
                vm.prank($.lowAmountTester);
                $.vToken.sweepIntoAtp();

                VmSafe.Log[] memory logs = vm.getRecordedLogs();

                $.latp = LATP(address(uint160(uint256(logs[logs.length - 1].topics[2]))));

                emit log_named_address("Low amount tester: LATP", address($.latp));
            }

            {
                for (uint256 i = 0; i < $.govParticipants.length; i++) {
                    emit log("Sweeping into ATP");
                    vm.recordLogs();
                    vm.prank($.govParticipants[i]);
                    $.vToken.sweepIntoAtp();

                    VmSafe.Log[] memory logs = vm.getRecordedLogs();
                    $.govParticipantAtps[i] = NCATP(address(uint160(uint256(logs[logs.length - 1].topics[2]))));
                    // emit log_named_address(string.concat("Gov participant ", vm.toString(i), ": NCATP"), address($.govParticipantAtps[i]));
                }
            }

            ATPWithdrawableAndClaimableStaker staker = ATPWithdrawableAndClaimableStaker(address($.ncatp.getStaker()));

            emit log("Stake amount tester: Upgrading staker implementation");
            vm.prank($.stakeAmountTester);
            $.ncatp.upgradeStaker(StakerVersion.wrap(1));

            emit log("Stake amount tester: Updating staker operator");
            vm.prank($.stakeAmountTester);
            $.ncatp.updateStakerOperator($.stakeAmountTester);

            {
                emit log("Stake amount tester: Approving staker");
                uint256 activationThreshold = $.rollup.getActivationThreshold();
                vm.prank($.stakeAmountTester);
                $.ncatp.approveStaker(activationThreshold);
            }

            emit log("Low amount tester: Upgrading staker implementation");
            vm.prank($.lowAmountTester);
            $.latp.upgradeStaker(StakerVersion.wrap(1));

            emit log("Low amount tester: Updating staker operator");
            vm.prank($.lowAmountTester);
            $.latp.updateStakerOperator($.lowAmountTester);

            {
                emit log("Low Amount tester: Approving staker");
                uint256 activationThreshold = $.rollup.getActivationThreshold();
                vm.prank($.lowAmountTester);
                $.latp.approveStaker(activationThreshold);
            }

            {
                for (uint256 i = 0; i < $.govParticipants.length; i++) {
                    emit log("Upgrading gov participant staker implementation");
                    vm.prank($.govParticipants[i]);
                    $.govParticipantAtps[i].upgradeStaker(StakerVersion.wrap(1));

                    emit log("Updating gov participant staker operator");
                    vm.prank($.govParticipants[i]);
                    $.govParticipantAtps[i].updateStakerOperator($.govParticipants[i]);

                    emit log("Approving gov participant staker");
                    vm.prank($.govParticipants[i]);
                    $.govParticipantAtps[i].approveStaker(uint256(type(uint128).max));
                }
            }

            uint256 version = $.rollup.getVersion();

            emit log("Staking");
            vm.prank($.stakeAmountTester);
            staker.stake(
                version,
                attester,
                BN254Lib.G1Point({
                    x: uint256(0x179a0fe721fe16e1ff5f6b971e57e36b78a909672fa397af6bb835d5a3956200),
                    y: uint256(0x261d29efbe7eab70a67d98359834dfa2b6d1637a3bd9347333463925b481262b)
                }),
                BN254Lib.G2Point({
                    x0: uint256(0x1a275e27317ebccca6d5a868c77297b2a8172700dc9fedeb1dff7e1e5a65ae1b),
                    x1: uint256(0x052839eea77e93786f3bf29f167ea9a4ad3455afad701fe4852dc5a4925f8fa0),
                    y0: uint256(0x253d74da0bc3e79fe8ef98857fa0226073e83dfb85182acc6359b5adcb438e4a),
                    y1: uint256(0x246f4a81eb09f66b11dbb0061eb0edd8c0e54661403402a28dd927268c0ba509)
                }),
                BN254Lib.G1Point({
                    x: uint256(0x28ba4648dff0b6fbc39e063f686bbb4a3a2cb6811d4bea0cffb32a307e4f7972),
                    y: uint256(0x0eff964241196de330ce488523fe5f56ace26552d6fe9483b61fb70aef737d09)
                }),
                true
            );

            emit log("Flushing entry queue");
            $.rollup.flushEntryQueue(1);

            vm.warp(block.timestamp + 1 days);
            emit log_named_uint("Warped to", block.timestamp);
        }

        t.proposer = GovernanceProposer(vm.parseJsonAddress(json, ".governanceProposerAddress"));

        {
            // Jump to the point in time where accelerated lock can pass
            GovernanceAcceleratedLock governanceAcceleratedLock =
                GovernanceAcceleratedLock(vm.parseJsonAddress(json, ".twapDateGatedRelayer"));
            uint256 executableTimeAccelerated =
                governanceAcceleratedLock.START_TIME() + governanceAcceleratedLock.SHORTER_LOCK_TIME();

            if (block.timestamp < executableTimeAccelerated) {
                vm.warp(executableTimeAccelerated);
                emit log_named_uint("Warped to", block.timestamp);
            }
        }

        t.governance = Governance(vm.parseJsonAddress(json, ".governanceAddress"));
        vm.label(address(t.governance), "governance");

        // The low amount staker deposits into gov and should be able to vote on proposals
        {
            uint256 latpBalance = $.token.balanceOf(address($.latp));
            address lowAmountStaker = address($.latp.getStaker());
            // Deposit the balance into gov
            emit log("Staker Low Amounts LATP: Deposit into governance");
            vm.prank($.lowAmountTester);
            IATPNonWithdrawableStaker(lowAmountStaker).depositIntoGovernance(latpBalance);

            emit log_named_decimal_uint("Staker Low Amounts LATP: LATP balance", $.token.balanceOf(address($.latp)), 18);
            emit log_named_decimal_uint(
                "Staker Low Amounts LATP: Gov balance", $.token.balanceOf(address(t.governance)), 18
            );
        }

        {
            // Gov participants deposit into gov and should be able to vote on proposals
            emit log("Gov participant: Deposit into governance");
            for (uint256 i = 0; i < $.govParticipants.length; i++) {
                uint256 balance = $.token.balanceOf(address($.govParticipantAtps[i]));
                address staker = address($.govParticipantAtps[i].getStaker());
                vm.prank($.govParticipants[i]);
                IATPNonWithdrawableStaker(staker).depositIntoGovernance(balance);
            }
        }

        {
            // NOTE:  Creating a payload that we can use for governance that will register a staker implementation
            //        and make it possible to unlock assets + trade with the uniswap pool.
            t.payload90 = new Payload90(
                IATPRegistry(vm.parseJsonAddress(json, ".atpRegistryAuction")),
                IRollupRegistry(vm.parseJsonAddress(json, ".registryAddress")),
                IERC20(vm.parseJsonAddress(json, ".stakingAssetAddress")),
                StakingRegistry(vm.parseJsonAddress(json, ".stakingRegistry")),
                IVirtualLBPStrategyBasic(payable(vm.parseJsonAddress(json, ".virtualLBP"))),
                vm.parseJsonAddress(json, ".twapDateGatedRelayer")
            );
        }

        emit log("Signal payload");
        vm.prank(attester);
        t.proposer.signal(IPayload(address(t.payload90)));

        uint256 currentRound = t.proposer.getCurrentRound();

        emit log("Warp forward in time to next round");

        // Jumps one round into the future.
        uint256 timeJump = t.proposer.ROUND_SIZE() * $.rollup.getSlotDuration();
        vm.warp(block.timestamp + timeJump);
        emit log_named_uint("Warped to", block.timestamp);

        emit log("Submitting round winner");
        t.proposer.submitRoundWinner(currentRound);

        uint256 proposalId = t.governance.proposalCount() - 1;

        GovernanceConfiguration memory govConfig = t.governance.getConfiguration();

        emit log("Warp forward in time past voting delay");
        vm.warp(block.timestamp + Timestamp.unwrap(govConfig.votingDelay) + 1);
        emit log_named_uint("Warped to", block.timestamp);

        {
            uint256 power = t.governance.powerNow(address($.latp.getStaker()));
            address lowAmountStaker = address($.latp.getStaker());
            emit log_named_decimal_uint("Staker Low Amounts LATP: POWER", power, 18);
            emit log("Staker Low Amounts LATP: Vote in governance");
            vm.prank($.lowAmountTester);
            IATPNonWithdrawableStaker(lowAmountStaker).voteInGovernance(proposalId, power, true);
        }

        {
            emit log("Gov participant: Vote in governance");
            for (uint256 i = 0; i < $.govParticipants.length; i++) {
                uint256 power = t.governance.powerNow(address($.govParticipantAtps[i].getStaker()));
                address staker = address($.govParticipantAtps[i].getStaker());
                vm.prank($.govParticipants[i]);
                IATPNonWithdrawableStaker(staker).voteInGovernance(proposalId, power, true);
            }
        }

        emit log("Voting using the rollup");
        $.rollup.vote(proposalId);

        emit log("Warp forward in time past voting duration and execution delay");
        vm.warp(
            block.timestamp + Timestamp.unwrap(govConfig.votingDuration) + Timestamp.unwrap(govConfig.executionDelay)
                + 1
        );
        emit log_named_uint("Warped to", block.timestamp);

        // Ensure that we have added a new staker to the registry
        IRegistry atpRegistry = IATPFactory(vm.parseJsonAddress(json, ".atpFactoryAuction")).getRegistry();
        uint256 nextStakerVersion = StakerVersion.unwrap(atpRegistry.getNextStakerVersion());

        emit log("Executing proposal");

        t.governance.execute(proposalId);

        emit log("Checking that new staker was added and payload was executed");

        assertEq(
            StakerVersion.unwrap(atpRegistry.getNextStakerVersion()), nextStakerVersion + 1, "did not add new staker"
        );

        emit log("Successfully executed proposal");

        // Withdraw from Gov - then claim | lATP lock should be reduced to 90 days - and thus the latp should be claimable
        {
            address lowAmountStaker = address($.latp.getStaker());

            uint256 powerAt = t.governance.powerNow(lowAmountStaker);
            emit log_named_uint("Staker Low Amounts LATP: Power at withdrawal", powerAt);

            emit log("Staker Low Amounts LATP: Initiate withdrawal from governance");
            vm.prank($.lowAmountTester);
            uint256 withdrawalId = IATPNonWithdrawableStaker(lowAmountStaker).initiateWithdrawFromGovernance(powerAt);

            // Finalize gov withdrawal - go past withdrawal delay
            emit log("Staker Low Amounts LATP: Finalizing withdrawal from governance");
            uint256 withdrawalTimestamp = Timestamp.unwrap(t.governance.getWithdrawal(withdrawalId).unlocksAt);
            vm.warp(withdrawalTimestamp + 1);
            emit log_named_uint("Warped to", block.timestamp);
            t.governance.finalizeWithdraw(withdrawalId);

            emit log("Low amount tester: Claiming tokens - should claim tokens as past global lock end time");
            vm.prank($.lowAmountTester);
            $.latp.claim();

            emit log_named_decimal_uint("Low amount tester: LATP balance", $.token.balanceOf(address($.latp)), 18);
            emit log_named_decimal_uint(
                "Low amount tester: Beneficiary balance", $.token.balanceOf($.lowAmountTester), 18
            );
        }

        // we want to see that we have also migrated. But we need uniswap to be deployed for that.
        if (block.chainid == 31337) {
            emit log("On anvil, won't try to migrate position");
            emit log("================================");
            return;
        }

        emit log("We are not on anvil, so we will try to migrate and trade as well");

        IVirtualLBPStrategyBasic strategy = IVirtualLBPStrategyBasic(payable(vm.parseJsonAddress(json, ".virtualLBP")));
        vm.label(address(strategy), "strategy");
        vm.label(address(strategy.positionManager()), "positionManager");
        vm.label(address(strategy.positionRecipient()), "positionRecipient");
        {
            uint256 migrationBlock = strategy.migrationBlock();
            vm.roll(migrationBlock);
        }

        // Sweep such that there are tokens in the setup that can be

        emit log("Sweeping currency from auction");
        $.auction.sweepCurrency();

        {
            uint256 before = $.token.balanceOf(address(WALLETS.twapTokenRecipient));
            emit log("Sweeping unsold tokens from auction");
            $.auction.sweepUnsoldTokens();
            assertGt($.token.balanceOf(address(WALLETS.twapTokenRecipient)) - before, 0, "No unsold tokens swept");
        }

        emit log_named_decimal_uint("Strategy Ether balance ", address(strategy).balance, 18);
        emit log_named_decimal_uint(
            "Strategy vtoken balance ", IERC20(strategy.token()).balanceOf(address(strategy)), 18
        );
        emit log_named_decimal_uint("Strategy underlying balance", $.token.balanceOf(address(strategy)), 18);

        emit log("Migrating");
        strategy.migrate();

        emit log_named_decimal_uint("Strategy Ether balance ", address(strategy).balance, 18);
        emit log_named_decimal_uint(
            "Strategy vtoken balance ", IERC20(strategy.token()).balanceOf(address(strategy)), 18
        );
        emit log_named_decimal_uint("Strategy underlying balance", $.token.balanceOf(address(strategy)), 18);

        vm.roll(strategy.sweepBlock());

        {
            emit log("Sweeping tokens from strategy");
            uint256 before = IERC20(strategy.UNDERLYING_TOKEN()).balanceOf(address(WALLETS.auctionOperator));

            vm.prank(WALLETS.auctionOperator);
            strategy.sweepToken();
            assertGt(
                IERC20(strategy.UNDERLYING_TOKEN()).balanceOf(address(WALLETS.auctionOperator)) - before,
                0,
                "No tokens swept"
            );
            emit log_named_decimal_uint(
                "Operator underlying balance",
                IERC20(strategy.UNDERLYING_TOKEN()).balanceOf(address(WALLETS.auctionOperator)),
                18
            );
        }

        {
            emit log("Sweeping currency from strategy");
            uint256 before = address(WALLETS.auctionOperator).balance;

            vm.prank(WALLETS.auctionOperator);
            strategy.sweepCurrency();

            assertGt(address(WALLETS.auctionOperator).balance - before, 0, "No currency swept");
        }

        emit log_named_decimal_uint("Strategy Ether balance ", address(strategy).balance, 18);
        emit log_named_decimal_uint(
            "Strategy token balance ", IERC20(strategy.token()).balanceOf(address(strategy)), 18
        );
        emit log_named_decimal_uint(
            "Strategy underlying balance", IERC20(strategy.UNDERLYING_TOKEN()).balanceOf(address(strategy)), 18
        );

        // @note For IVirtualLBPStrategyBasic, the pool uses UNDERLYING_TOKEN, not token()
        address currency = strategy.currency();

        emit log_named_address("Currency address", currency);
        emit log_named_address("Token address   ", address($.token));

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(currency < address($.token) ? currency : address($.token)),
            currency1: Currency.wrap(currency < address($.token) ? address($.token) : currency),
            fee: strategy.poolLPFee(),
            tickSpacing: strategy.poolTickSpacing(),
            hooks: IHooks(address(strategy))
        });

        {
            PoolId poolId = key.toId();
            emit log("Querying pool amounts");
            (uint256 amount0, uint256 amount1) = _uniswapValues(strategy, poolId);

            emit log_named_decimal_uint("Pool amount0 (currency)", amount0, 18);
            emit log_named_decimal_uint("Pool amount1 (token)   ", amount1, 18);
        }

        // Try a simple swap: buy some tokens with currency
        emit log("Testing swap: buying tokens with currency");

        {
            // Get balances before swap
            t.currencyBefore = address($.stakeAmountTester).balance;
            t.tokenBefore = $.token.balanceOf(address($.stakeAmountTester));

            uint256 amountIn = 1 ether;
            emit log_named_decimal_uint("Buying tokens for currency", amountIn, 18);

            // Perform the swap
            _testSwap($.stakeAmountTester, key, amountIn);

            // Get balances after swap
            t.currencyAfter = address($.stakeAmountTester).balance;
            t.tokenAfter = $.token.balanceOf(address($.stakeAmountTester));

            emit log_named_decimal_uint("Currency spent            ", t.currencyBefore - t.currencyAfter, 18);
            emit log_named_decimal_uint("Tokens received           ", t.tokenAfter - t.tokenBefore, 18);
        }

        {
            PoolId poolId = key.toId();
            emit log("Querying pool amounts");
            (uint256 amount0, uint256 amount1) = _uniswapValues(strategy, poolId);

            emit log_named_decimal_uint("Pool amount0 (currency)", amount0, 18);
            emit log_named_decimal_uint("Pool amount1 (token)   ", amount1, 18);
        }

        emit log("Successfully swapped");

        {
            emit log("Exit the LP position. Impersonating governance");

            address holder = address(t.treasury);

            emit log_named_decimal_uint("treasury ETH   balance", holder.balance, 18);
            emit log_named_decimal_uint("treasury token balance", $.token.balanceOf(holder), 18);

            t.manager = strategy.positionManager();
            // Abuse that we are running in a simulation where no-one else have created positions.
            t.tokenId = t.manager.nextTokenId() - 1;

            t.actions = abi.encodePacked(uint8(Actions.BURN_POSITION), uint8(Actions.TAKE_PAIR));

            t.params = new bytes[](2);
            t.params[0] = abi.encode(t.tokenId, uint128(0), uint128(0), bytes(""));
            t.params[1] = abi.encode(key.currency0, key.currency1, holder);

            emit log("Liquidate the position");
            t.plan = abi.encode(t.actions, t.params);

            bytes memory data =
                abi.encodeWithSelector(IPositionManager.modifyLiquidities.selector, t.plan, block.timestamp + 300);

            // We are going to mock the governance returns, to make it past the activation

            vm.prank(address(t.governance));
            vm.expectRevert();
            ProtocolTreasury(payable(t.treasury)).relay(address(t.manager), data, 0);

            t.currencyBefore = t.treasury.balance;

            // We mock the insider atp registry to say that activation is in the past.
            t.insiderAtpRegistry = address(ProtocolTreasury(payable(t.treasury)).ATP_REGISTRY());
            vm.mockCall(t.insiderAtpRegistry, IATPRegistry.getExecuteAllowedAt.selector, abi.encode(uint256(0)));

            vm.prank(address(t.governance));
            ProtocolTreasury(payable(t.treasury)).relay(address(t.manager), data, 0);

            emit log_named_decimal_uint("treasury ETH   balance", holder.balance, 18);
            emit log_named_decimal_uint("treasury token balance", $.token.balanceOf(holder), 18);

            assertGt(t.treasury.balance, t.currencyBefore);
        }

        emit log("================================");
    }

    function simpleTreasuryActions() public snapshotted {
        emit log("================================");
        emit log("Scenario: protocol treasury actions ");

        string memory json = _loadJson();

        ProtocolTreasury treasury = ProtocolTreasury(payable(vm.parseJsonAddress(json, ".protocolTreasuryAddress")));
        IERC20 token = IERC20(vm.parseJsonAddress(json, ".stakingAssetAddress"));
        address governance = vm.parseJsonAddress(json, ".governanceAddress");

        emit log_named_decimal_uint("Treasury ether balance", address(treasury).balance, 18);
        emit log_named_decimal_uint("Treasury aztec balance", token.balanceOf(address(treasury)), 18);

        // Send some eth to the treasury.
        address funder = makeAddr("funder");
        vm.deal(funder, 100 ether);

        emit log("Funding the Treasury");

        vm.prank(funder);
        (bool success,) = address(treasury).call{value: 50 ether}("");
        assertTrue(success);
        assertEq(address(treasury).balance, 50 ether);
        assertEq(funder.balance, 50 ether);

        emit log_named_decimal_uint("Treasury ether balance", address(treasury).balance, 18);
        emit log_named_decimal_uint("Treasury aztec balance", token.balanceOf(address(treasury)), 18);

        emit log("Now we wish to transfer and aztec eth from the Treasury to funder, why not");
        emit log("To do this, we fake a gov proposal AFTER insiders can do stuff");
        emit log("We also jump far enough into the future for the gate to stop");

        vm.warp(treasury.GATED_UNTIL());

        Proposal memory fakeProposal;
        fakeProposal.creation = Timestamp.wrap(treasury.getActivationTimestamp() + 1);

        uint256 treasuryBalance = token.balanceOf(address(treasury));

        vm.mockCall(governance, IGovernance.getProposal.selector, abi.encode(fakeProposal));
        vm.prank(governance);
        treasury.relay(funder, "", 25 ether);
        vm.prank(governance);
        treasury.relay(address(token), abi.encodeWithSelector(IERC20.transfer.selector, funder, 25 ether), 0);

        assertEq(address(treasury).balance, 25 ether);
        assertEq(token.balanceOf(address(treasury)), treasuryBalance - 25 ether);
        assertEq(funder.balance, 75 ether);
        assertEq(token.balanceOf(funder), 25 ether);

        emit log_named_decimal_uint("Treasury ether balance", address(treasury).balance, 18);
        emit log_named_decimal_uint("Treasury aztec balance", token.balanceOf(address(treasury)), 18);
        emit log("================================");
    }

    struct TempValues {
        uint256 currencyBefore;
        uint256 tokenBefore;
        uint256 currencyAfter;
        uint256 tokenAfter;
        address treasury;
        IPositionManager manager;
        uint256 tokenId;
        bytes actions;
        bytes[] params;
        bytes plan;
        Payload90 payload90;
        Governance governance;
        GovernanceProposer proposer;
        address insiderAtpRegistry;
    }

    function _uniswapValues(IVirtualLBPStrategyBasic strategy, PoolId poolId)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        // Get current pool state
        (uint160 sqrtPriceX96,,,) = strategy.poolManager().getSlot0(poolId);

        // Get total liquidity in the pool
        uint128 liquidity = strategy.poolManager().getLiquidity(poolId);

        // For full range position, use the min/max ticks based on the pool's tick spacing
        int24 tickSpacing = strategy.poolTickSpacing();
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtPriceAtTick(TickMath.minUsableTick(tickSpacing));
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtPriceAtTick(TickMath.maxUsableTick(tickSpacing));

        // Calculate token amounts from liquidity
        // This uses the Uniswap v3/v4 math for converting liquidity to amounts
        if (sqrtPriceX96 <= sqrtPriceLowerX96) {
            // Current price is below the range, all liquidity is in token0
            amount0 = _getAmount0ForLiquidity(sqrtPriceLowerX96, sqrtPriceUpperX96, liquidity);
        } else if (sqrtPriceX96 < sqrtPriceUpperX96) {
            // Current price is within the range, liquidity is split between both tokens
            amount0 = _getAmount0ForLiquidity(sqrtPriceX96, sqrtPriceUpperX96, liquidity);
            amount1 = _getAmount1ForLiquidity(sqrtPriceLowerX96, sqrtPriceX96, liquidity);
        } else {
            // Current price is above the range, all liquidity is in token1
            amount1 = _getAmount1ForLiquidity(sqrtPriceLowerX96, sqrtPriceUpperX96, liquidity);
        }

        return (amount0, amount1);
    }

    function _getAmount0ForLiquidity(uint160 sqrtPriceAX96, uint160 sqrtPriceBX96, uint128 liquidity)
        internal
        pure
        returns (uint256 amount0)
    {
        if (sqrtPriceAX96 > sqrtPriceBX96) (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        return FullMath.mulDiv(
            uint256(liquidity) << FixedPoint96.RESOLUTION, sqrtPriceBX96 - sqrtPriceAX96, sqrtPriceBX96
        ) / sqrtPriceAX96;
    }

    function _getAmount1ForLiquidity(uint160 sqrtPriceAX96, uint160 sqrtPriceBX96, uint128 liquidity)
        internal
        pure
        returns (uint256 amount1)
    {
        if (sqrtPriceAX96 > sqrtPriceBX96) (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        return FullMath.mulDiv(liquidity, sqrtPriceBX96 - sqrtPriceAX96, FixedPoint96.Q96);
    }

    function _testSwap(address _caller, PoolKey memory key, uint256 amountIn) internal {
        // UniversalRouter address on Sepolia
        IUniversalRouter router;
        if (block.chainid == 1) {
            router = IUniversalRouter(0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af);
        } else {
            router = IUniversalRouter(0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b);
        }

        // Determine swap direction: we want to swap currency for token
        // zeroForOne = true if currency is currency0, false if currency is currency1
        bool zeroForOne = Currency.unwrap(key.currency0) < Currency.unwrap(key.currency1);

        // Determine which currency we're swapping in and which we're receiving
        Currency currencyIn = zeroForOne ? key.currency0 : key.currency1;
        Currency currencyOut = zeroForOne ? key.currency1 : key.currency0;

        // Encode the Universal Router command (V4_SWAP = 0x10)
        bytes memory commands = abi.encodePacked(uint8(0x10));

        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountIn: uint128(amountIn),
                amountOutMinimum: 0, // Accept any amount (no slippage protection for testing)
                hookData: ""
            })
        );
        // SETTLE_ALL and TAKE_ALL expect Currency types (not unwrapped addresses)
        params[1] = abi.encode(currencyIn, amountIn);
        params[2] = abi.encode(currencyOut, uint256(0));

        // Combine actions and params into inputs for the V4_SWAP command
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);

        // Execute the swap via the router
        // For native ETH, send as value; for ERC20, need to approve first
        if (Currency.unwrap(currencyIn) == address(0)) {
            // Native currency
            vm.deal(_caller, amountIn + 1 ether);
            vm.prank(_caller);
            router.execute{value: amountIn}(commands, inputs, block.timestamp + 60);
        } else {
            // ERC20 currency - need to approve
            vm.prank(_caller);
            IERC20(Currency.unwrap(currencyIn)).approve(address(router), amountIn);
            vm.prank(_caller);
            router.execute(commands, inputs, block.timestamp + 60);
        }
    }

    // Need to be able to receive ETH
    receive() external payable {}
}
