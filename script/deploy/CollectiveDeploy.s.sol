// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {TestBase} from "@aztec-test/base/Base.sol";

import {DeployAztecL1Contracts} from "./rollup/DeployAztecL1Contracts.s.sol";
import {DeployGenesisSaleContracts} from "./sale/DeployGenesisSaleContracts.s.sol";
import {DeployAuction} from "./twap/DeployAuction.s.sol";

import {TestERC20} from "@aztec/mock/TestERC20.sol";
import {DateGatedRelayer} from "@aztec/periphery/DateGatedRelayer.sol";
import {
    FoundationPayload,
    FoundationPayloadConfig,
    FoundationAztecConfig,
    FoundationTwapConfig,
    FoundationGenesisSaleConfig,
    TwapGovPayloadConfig,
    ProtocolTreasuryConfig,
    FoundationFundingConfig
} from "./FoundationPayload.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {Ownable2Step} from "@oz/access/Ownable2Step.sol";
import {Address} from "@oz/utils/Address.sol";

import {GenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";
import {IgnitionParticipantSoulbound} from "src/soulbound/IgnitionParticipantSoulbound.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {NCATP} from "@atp/atps/noclaim/NCATP.sol";
import {IInstance} from "@aztec/core/interfaces/IInstance.sol";

import {IRegistry, StakerVersion} from "@atp/Registry.sol";
import {VmSafe} from "lib/forge-std/src/Vm.sol";
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";
import {ATPWithdrawableAndClaimableStaker} from "src/staking/ATPWithdrawableAndClaimableStaker.sol";
import {IWhitelistProvider} from "src/soulbound/providers/IWhitelistProvider.sol";
import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";
import {GovernanceProposer} from "@aztec/governance/proposer/GovernanceProposer.sol";
import {VirtualAztecToken} from "src/uniswap-periphery/VirtualAztecToken.sol";
import {IVirtualLBPStrategyBasic} from "src/uniswap-periphery/IVirtualLBPStrategyBasic.sol";

import {OwnershipLogging} from "./utilities/OwnershipLogging.sol";
import {IATPFactory} from "@atp/ATPFactory.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {IRegistry as IRollupRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";
import {StakingRegistry, IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {Governance} from "@aztec/governance/Governance.sol";
import {Configuration as GovernanceConfiguration} from "@aztec/governance/interfaces/IGovernance.sol";
import {Timestamp} from "@aztec/shared/libraries/TimeMath.sol";

import {AztecConfiguration} from "./rollup/AztecConfiguration.sol";
import {ConfigurationVariant, ChainEnvironment, SharedConfigGetter} from "./SharedConfig.sol";
import {IgnitionSharedDates} from "./IgnitionSharedDates.sol";
import {Payload90} from "./gov/Payload90.sol";
import {Scenarios} from "./utilities/Scenarios.sol";
import {ConfigurationLogging} from "./utilities/ConfigurationLogging.sol";

struct FoundationWallets {
    address deployer;
    address tokenOwner;
    address genesisSaleOwner;
    address twapTokenRecipient;
    address auctionOperator;
    address lowValueOwner;
}

struct FoundationActions {
    address[] targets;
    bytes[] datas;
}

contract CollectiveDeploy is TestBase {
    using Address for address;

    ConfigurationVariant public CONFIGURATION_VARIANT;
    ChainEnvironment public CHAIN_ENVIRONMENT;

    FoundationWallets internal WALLETS;
    DeployAztecL1Contracts internal aztec;
    DeployGenesisSaleContracts internal genesisSale;
    DeployAuction internal twap;

    FoundationActions internal foundationActionsStored;

    Payload90 internal payload90;

    OwnershipLogging internal ownershipLogging;
    Scenarios internal scenarios;

    address internal STAKING_ASSET_ADDRESS;

    uint256 internal funderBalance;

    function setUp() public {
        aztec = new DeployAztecL1Contracts();
        genesisSale = new DeployGenesisSaleContracts();
        twap = new DeployAuction();
        ownershipLogging = new OwnershipLogging();
        scenarios = new Scenarios();

        SharedConfigGetter sharedConfigGetter = new SharedConfigGetter();
        CONFIGURATION_VARIANT = sharedConfigGetter.getConfigurationVariant();
        CHAIN_ENVIRONMENT = sharedConfigGetter.getChainEnvironment();

        if (CHAIN_ENVIRONMENT != ChainEnvironment.FRESH_NETWORK) {
            WALLETS = FoundationWallets({
                deployer: 0x85e51a78FE8FE21d881894206A9adbf54e3Df8c3,
                tokenOwner: 0x13620833364653fa125cCDD7Cf54b9e4A22AB6d9,
                genesisSaleOwner: 0x13620833364653fa125cCDD7Cf54b9e4A22AB6d9,
                // This should be the same address as the VIRTUAL_AZTEC_TOKEN constructor value FOUNDATION
                twapTokenRecipient: 0x13620833364653fa125cCDD7Cf54b9e4A22AB6d9,
                auctionOperator: 0x13620833364653fa125cCDD7Cf54b9e4A22AB6d9,
                lowValueOwner: 0x10EBE932BEC29688D2956688Bb9294C11A4a5657
            });

            STAKING_ASSET_ADDRESS = 0xA27EC0006e59f245217Ff08CD52A7E8b169E62D2;
        } else {
            WALLETS = FoundationWallets({
                deployer: vm.envAddress("DEPLOYER_ADDRESS"), // anvil 1 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 - if local // 0xdfe19Da6a717b7088621d8bBB66be59F2d78e924 if sepolia from ci
                tokenOwner: vm.envAddress("TESTING_FOUNDATION_ADDRESS"), // anvil 2 0x70997970C51812dc3A010C7d01b50e0d17dc79C8  - if local // 0xc55e125B5cD0965Fd8BCAeFbC3d2b72CDb94c918 if sepolia from ci
                genesisSaleOwner: 0xB91A570B2bFe219928ECb7D815c291818d512846,
                twapTokenRecipient: 0xBFdF6a252164343f9645A61FA3B7650f2214C69b,
                auctionOperator: 0x88B6A7A90B69228fB9af38652fE977D718e4F07b,
                lowValueOwner: vm.envAddress("DEPLOYER_ADDRESS")
            });
        }
    }

    function run() public {
        if (CHAIN_ENVIRONMENT == ChainEnvironment.FRESH_NETWORK) {
            // If we are a fresh network, deploy a token.
            vm.broadcast(WALLETS.deployer);
            TestERC20 stakingAsset = new TestERC20("STAKING_ASSET_CONTRACT", "STK", WALLETS.tokenOwner);

            vm.broadcast(WALLETS.tokenOwner);
            stakingAsset.mint(WALLETS.tokenOwner, 5e9 * 1e18);

            STAKING_ASSET_ADDRESS = address(stakingAsset);
        }

        funderBalance = IERC20(STAKING_ASSET_ADDRESS).balanceOf(WALLETS.tokenOwner);

        aztec.setEnv({_variant: CONFIGURATION_VARIANT, _foundationWallets: WALLETS, _asset: STAKING_ASSET_ADDRESS});

        emit log("## Deploying aztec contracts ##");
        aztec.run();

        emit log("## Deploying genesis sale contracts ##");
        genesisSale.setEnv({
            _configurationVariant: CONFIGURATION_VARIANT,
            _chainEnvironment: CHAIN_ENVIRONMENT,
            _foundationWallets: WALLETS,
            _stakingAssetAddress: address(aztec.STAKING_ASSET_CONTRACT()),
            _rollupAddress: address(aztec.ROLLUP_CONTRACT()),
            _rollupRegistryAddress: address(aztec.REGISTRY_CONTRACT())
        });
        genesisSale.run();

        emit log("## Deploying auction ##");

        DeployGenesisSaleContracts.DeployedContracts memory genesisSaleContracts = genesisSale.getDeployedContracts();

        twap.setEnv({
            _configurationVariant: CONFIGURATION_VARIANT,
            _chainEnvironment: CHAIN_ENVIRONMENT,
            _foundationWallets: WALLETS,
            _governanceAddress: address(aztec.GOVERNANCE_CONTRACT()),
            _stakingAssetAddress: address(aztec.STAKING_ASSET_CONTRACT()),
            _foundationPayload: address(aztec.FOUNDATION_PAYLOAD_CONTRACT()),
            _protocolTreasuryAddress: address(aztec.PROTOCOL_TREASURY_CONTRACT()),
            _genesisSequencerSale: address(genesisSaleContracts.genesisSequencerSale),
            _soulbound: address(genesisSaleContracts.soulboundToken),
            _atpWithdrawableAndClaimableStaker: address(genesisSaleContracts.atpWithdrawableAndClaimableStaker)
        });
        twap.run();

        // TODO: We will only be broadcasting if on the fresh network as we have explicit impersonate for anvil
        // as part of the `bootstrap.sh`.

        bool broadcast = CHAIN_ENVIRONMENT == ChainEnvironment.FRESH_NETWORK;

        emit log("Configuring foundation payload");
        foundationPayloadSetup();

        // NOTE: We write the file here since it allow us to either execute the following as "broadcast" or as
        // separate actions performed in a separate run.
        writeDeploymentFile();

        foundationActions(broadcast);

        foundationPayloadRun(broadcast);

        twap.assertTokenSplits();
    }

    function simulateStep2And3() public {
        // A helper function used to easily simulate step 2 and 3 for the foundation and ensure effects match
        foundationActions(false);
        foundationPayloadRun(false);

        ConfigurationLogging logger = new ConfigurationLogging();

        logger.log_configuration();
    }

    function foundationActions(bool _broadcast) public {
        // Step 2. Simulate or broadcasts the actions that foundation needs to take using the token owner.

        string memory json = _loadJson();
        emit log("Executing foundation payload");

        FoundationPayload foundationPayload = FoundationPayload(vm.parseJsonAddress(json, ".foundationPayloadAddress"));

        address target0 = vm.parseJsonAddress(json, ".foundationActionsTarget0");
        address target1 = vm.parseJsonAddress(json, ".foundationActionsTarget1");
        bytes memory data0 = vm.parseJsonBytes(json, ".foundationActionsData0");
        bytes memory data1 = vm.parseJsonBytes(json, ".foundationActionsData1");

        if (_broadcast) {
            vm.startBroadcast(WALLETS.tokenOwner);
        } else {
            vm.startPrank(WALLETS.tokenOwner);
        }

        target0.functionCall(data0);
        target1.functionCall(data1);

        if (_broadcast) {
            vm.stopBroadcast();
        } else {
            vm.stopPrank();
        }
    }

    function foundationPayloadRun(bool _broadcast) public {
        // Step 3. Simulate or broadcasts the execution of the foundation payload AND validates the state with scenarios.
        string memory json = _loadJson();
        emit log("Executing foundation payload");

        FoundationPayload foundationPayload = FoundationPayload(vm.parseJsonAddress(json, ".foundationPayloadAddress"));

        if (_broadcast) {
            emit log("Running foundation payload");
            vm.broadcast(WALLETS.deployer);
            foundationPayload.run();
        } else {
            vm.prank(WALLETS.deployer);
            foundationPayload.run();
        }

        foundationAssertions();

        emit log("## Running scenarios ##");

        scenarios.sale();
        scenarios.twap();

        if (CONFIGURATION_VARIANT != ConfigurationVariant.IGNITION) {
            // We only run the gov for non-ignition configurations as we cannot add 500 validators and run 600 signals
            // inside a foundry test.
            scenarios.gov();
        }

        scenarios.simpleTreasuryActions();

        assertAmin();

        assert_and_log_ownerships();
    }

    function foundationPayloadSetup() public {
        FoundationPayload foundationPayload = aztec.FOUNDATION_PAYLOAD_CONTRACT();
        DeployGenesisSaleContracts.DeployedContracts memory genesisSaleContracts = genesisSale.getDeployedContracts();
        DeployAuction.DeployedAuctionContracts memory twapContracts = twap.getDeployedContracts();

        IRegistry atpRegistry = IATPFactory(twapContracts.atpFactoryAuction).getRegistry();
        IERC20 stakingAsset = IERC20(aztec.STAKING_ASSET_CONTRACT());
        IRollupRegistry rollupRegistry = IRollupRegistry(address(aztec.REGISTRY_CONTRACT()));

        TwapGovPayloadConfig memory govPayloadConfig = TwapGovPayloadConfig({
            atpRegistry: address(atpRegistry),
            dateGatedRelayerShort: twapContracts.dateGatedRelayerShort
        });

        FoundationPayloadConfig memory foundationPayloadConfiguration = FoundationPayloadConfig({
            funder: WALLETS.tokenOwner,
            foundationFunding: FoundationFundingConfig({mintToFunder: 100_000_000e18}),
            aztec: FoundationAztecConfig({
                token: address(aztec.FEE_ASSET_CONTRACT()),
                governance: address(aztec.GOVERNANCE_CONTRACT()),
                rewardDistributor: address(aztec.REGISTRY_CONTRACT().getRewardDistributor()),
                flushRewarder: address(aztec.FLUSH_REWARDER_CONTRACT()),
                coinIssuer: address(aztec.COIN_ISSUER_CONTRACT()),
                protocolTreasury: address(aztec.PROTOCOL_TREASURY_CONTRACT()),
                tokensToRewardDistributor: aztec.getRewardDistributorFunding(),
                tokensToFlushRewarder: aztec.getFlushRewardInitialFunding()
            }),
            genesisSale: FoundationGenesisSaleConfig({
                genesisSequencerSale: address(genesisSaleContracts.genesisSequencerSale),
                tokensToGenesisSequencerSale: genesisSaleContracts.genesisSequencerSupply
            }),
            twap: FoundationTwapConfig({
                virtualToken: address(twapContracts.virtualAztecToken),
                tokensToVirtualToken: twapContracts.tokenLauncherTotalSupply,
                permit2: address(twapContracts.permit2),
                tokenLauncher: address(twapContracts.tokenLauncher),
                distributionParams: twapContracts.distributionParams,
                generatedSalt: twapContracts.generatedSalt,
                auction: address(twapContracts.auction)
            }),
            govPayload: govPayloadConfig,
            protocolTreasuryConfig: ProtocolTreasuryConfig({
                tokensForTreasury: 505_000_000e18 // 4.88% of supply
            })
        });

        vm.broadcast(WALLETS.deployer);
        foundationPayload.setConfig(foundationPayloadConfiguration);

        uint256 existingFundingAmount = foundationPayload.getApprovalAmount();
        address token = foundationPayloadConfiguration.aztec.token;

        address[2] memory targets = [token, token];
        bytes[2] memory datas = [
            abi.encodeWithSelector(Ownable.transferOwnership.selector, address(foundationPayload)),
            abi.encodeWithSelector(IERC20.approve.selector, address(foundationPayload), existingFundingAmount)
        ];

        emit log_named_address("Actions to be executed by foundation account", WALLETS.tokenOwner);
        for (uint256 i = 0; i < targets.length; i++) {
            emit log_named_address("\ttarget", targets[i]);
            emit log_named_bytes("\tdata  ", datas[i]);

            foundationActionsStored.targets.push(targets[i]);
            foundationActionsStored.datas.push(datas[i]);
        }
        emit log("");
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

    function assertAmin() public {
        if (CONFIGURATION_VARIANT == ConfigurationVariant.SCHEDULED_DEPLOYMENTS) {
            emit log("Skipping Amin assertions for scheduled deployments");
            return;
        }
        emit log("Asserting Amin");

        string memory json = _loadJson();

        IERC20 token = IERC20(vm.parseJsonAddress(json, ".stakingAssetAddress"));
        assertEq(token.balanceOf(vm.parseJsonAddress(json, ".rewardDistributorAddress")), 249_000_000e18);
        assertEq(token.balanceOf(vm.parseJsonAddress(json, ".flushRewarderAddress")), 1_000_000e18);
        assertEq(token.balanceOf(vm.parseJsonAddress(json, ".genesisSequencerSale")), 200_000_000e18);
        assertEq(token.balanceOf(vm.parseJsonAddress(json, ".virtualAztecToken")), 1_820_000_000e18);
        assertEq(token.balanceOf(vm.parseJsonAddress(json, ".protocolTreasuryAddress")), 505_000_000e18);
        assertEq(
            token.balanceOf(vm.parseJsonAddress(json, ".tokenOwnerAddress")),
            1_111_000_000e18 + 252_500_000e18 + 1_211_500_000e18,
            "invalid funder balance"
        );

        IERC20 vToken = IERC20(vm.parseJsonAddress(json, ".virtualAztecToken"));
        assertEq(vToken.balanceOf(vm.parseJsonAddress(json, ".twapAuction")), 1_547_000_000e18);
        assertEq(vToken.balanceOf(vm.parseJsonAddress(json, ".virtualLBP")), 273_000_000e18);

        // Sale
        assertTrue(GenesisSequencerSale(vm.parseJsonAddress(json, ".genesisSequencerSale")).saleEnabled());
        assertEq(
            Ownable(vm.parseJsonAddress(json, ".genesisSequencerSale")).owner(),
            vm.parseJsonAddress(json, ".genesisSaleOwnerAddress")
        );

        // Twap

        emit log("Amin assertions passed");
    }

    struct OwnerCheck {
        string contractLabel;
        string ownerLabel;
        string pendingOwnerLabel;
        bool checkPending;
    }

    function assert_and_log_ownerships() public {
        // NOTE:  We assert ownerships match what we expect, and for good measure we log them afterwards,
        //        making it simpler to catch potential issues where the assertions hold, e.g., the named
        //        foundation wallet `lowValueOwner` owns what it should, but the wallet itself might be wrong.
        //        There is a visualisation of the ownerships and roles in `ownerships-and-roles.png` in figures.

        string memory json = _loadJson();

        // Aztec Contracts Access Control (*ALMOST* same as in deploy l1 1contracts)
        OwnerCheck[8] memory aztecOwnerChecks = [
            OwnerCheck("gseAddress", "governanceAddress", "", false),
            OwnerCheck("registryAddress", "governanceAddress", "", false),
            OwnerCheck("flushRewarderAddress", "governanceAddress", "", false),
            OwnerCheck("coinIssuerAddress", "protocolTreasuryAddress", "", false),
            OwnerCheck("protocolTreasuryAddress", "governanceAddress", "", false),
            OwnerCheck("feeAssetAddress", "coinIssuerAddress", "", true),
            OwnerCheck("stakingAssetAddress", "coinIssuerAddress", "", true),
            OwnerCheck("rollupAddress", "governanceAddress", "", false)
        ];

        assertEq(Ownable(vm.parseJsonAddress(json, ".foundationPayloadAddress")).owner(), address(0));
        for (uint256 i = 0; i < aztecOwnerChecks.length; i++) {
            address c = vm.parseJsonAddress(json, string.concat(".", aztecOwnerChecks[i].contractLabel));
            address o = vm.parseJsonAddress(json, string.concat(".", aztecOwnerChecks[i].ownerLabel));
            assertEq(Ownable(c).owner(), o);

            if (aztecOwnerChecks[i].checkPending) {
                address p = bytes(aztecOwnerChecks[i].pendingOwnerLabel).length == 0
                    ? address(0)
                    : vm.parseJsonAddress(json, string.concat(".", aztecOwnerChecks[i].pendingOwnerLabel));
                assertEq(Ownable2Step(c).pendingOwner(), p);
            }
        }

        // Sale Access Control
        OwnerCheck[8] memory saleOwnerChecks = [
            OwnerCheck("atpFactory", "deployerAddress", "lowValueOwnerAddress", true),
            OwnerCheck("atpRegistry", "", "", true),
            OwnerCheck("zkPassportProvider", "lowValueOwnerAddress", "", false),
            OwnerCheck("predicateSanctionsProvider", "lowValueOwnerAddress", "", false),
            OwnerCheck("predicateSanctionsProviderSale", "lowValueOwnerAddress", "", false),
            OwnerCheck("predicateKYCProvider", "lowValueOwnerAddress", "", false),
            OwnerCheck("soulboundToken", "lowValueOwnerAddress", "", false),
            OwnerCheck("genesisSequencerSale", "genesisSaleOwnerAddress", "", false)
        ];
        for (uint256 i = 0; i < saleOwnerChecks.length; i++) {
            address c = vm.parseJsonAddress(json, string.concat(".", saleOwnerChecks[i].contractLabel));
            address o = bytes(saleOwnerChecks[i].ownerLabel).length == 0
                ? address(0)
                : vm.parseJsonAddress(json, string.concat(".", saleOwnerChecks[i].ownerLabel));
            assertEq(Ownable(c).owner(), o);

            if (saleOwnerChecks[i].checkPending) {
                address p = bytes(saleOwnerChecks[i].pendingOwnerLabel).length == 0
                    ? address(0)
                    : vm.parseJsonAddress(json, string.concat(".", saleOwnerChecks[i].pendingOwnerLabel));
                assertEq(Ownable2Step(c).pendingOwner(), p);
            }
        }

        // Auction Access Control
        OwnerCheck[6] memory auctionOwnerChecks = [
            OwnerCheck("auctionHook", "lowValueOwnerAddress", "", false),
            OwnerCheck("predicateAuctionScreeningProvider", "lowValueOwnerAddress", "", false),
            OwnerCheck("atpRegistryAuction", "foundationPayloadAddress", "twapDateGatedRelayer", true),
            OwnerCheck("virtualAztecToken", "foundationPayloadAddress", "", false),
            OwnerCheck("twapDateGatedRelayer", "governanceAddress", "", false),
            OwnerCheck("atpFactoryAuction", "", "", true)
        ];
        IVirtualLBPStrategyBasic strategy = IVirtualLBPStrategyBasic(payable(vm.parseJsonAddress(json, ".virtualLBP")));
        assertEq(
            address(strategy.GOVERNANCE()),
            vm.parseJsonAddress(json, ".twapDateGatedRelayer"),
            "invalid gov on strategy"
        );
        assertEq(
            address(strategy.operator()),
            vm.parseJsonAddress(json, ".auctionOperatorAddress"),
            "invalid gov on strategy"
        );
        assertEq(
            address(strategy.positionRecipient()),
            vm.parseJsonAddress(json, ".protocolTreasuryAddress"),
            "invalid gov on strategy"
        );
        IContinuousClearingAuction auction = IContinuousClearingAuction(vm.parseJsonAddress(json, ".twapAuction"));
        assertEq(
            address(auction.tokensRecipient()),
            vm.parseJsonAddress(json, ".twapTokenRecipientAddress"),
            "auction invalid token recipient"
        );
        assertEq(
            address(auction.fundsRecipient()),
            vm.parseJsonAddress(json, ".virtualLBP"),
            "auction invalid funds recipient"
        );
        for (uint256 i = 0; i < auctionOwnerChecks.length; i++) {
            address c = vm.parseJsonAddress(json, string.concat(".", auctionOwnerChecks[i].contractLabel));
            address o = bytes(auctionOwnerChecks[i].ownerLabel).length == 0
                ? address(0)
                : vm.parseJsonAddress(json, string.concat(".", auctionOwnerChecks[i].ownerLabel));
            assertEq(Ownable(c).owner(), o);

            if (auctionOwnerChecks[i].checkPending) {
                address p = bytes(auctionOwnerChecks[i].pendingOwnerLabel).length == 0
                    ? address(0)
                    : vm.parseJsonAddress(json, string.concat(".", auctionOwnerChecks[i].pendingOwnerLabel));
                assertEq(Ownable2Step(c).pendingOwner(), p);
            }
        }

        ownershipLogging.log_ownerships();
    }

    function foundationAssertions() public {
        string memory json = _loadJson();
        AztecConfiguration aztecConfiguration = new AztecConfiguration(CONFIGURATION_VARIANT);

        address token = vm.parseJsonAddress(json, ".stakingAssetAddress");
        address coinIssuer = vm.parseJsonAddress(json, ".coinIssuerAddress");
        address dgr365 = vm.parseJsonAddress(json, ".protocolTreasuryAddress");

        assertEq(Ownable(token).owner(), coinIssuer, "Token owner mismatch");
        assertEq(Ownable(coinIssuer).owner(), dgr365, "Coin issuer owner mismatch");

        address rewardDistributor = vm.parseJsonAddress(json, ".rewardDistributorAddress");
        assertEq(
            IERC20(token).balanceOf(rewardDistributor),
            aztecConfiguration.getRewardDistributorFunding(),
            "Reward distributor balance mismatch"
        );

        address flushRewarder = vm.parseJsonAddress(json, ".flushRewarderAddress");
        assertEq(
            IERC20(token).balanceOf(flushRewarder),
            aztecConfiguration.getFlushRewardConfiguration().initialFundingAmount,
            "Flush rewarder balance mismatch"
        );

        address auction = vm.parseJsonAddress(json, ".twapAuction");
        assertGt(auction.code.length, 0, "ContinuousClearingAuction address has no code");
        assertEq(
            IContinuousClearingAuction(auction).tokensRecipient(),
            vm.parseJsonAddress(json, ".twapTokenRecipientAddress"),
            "Tokens recipient mismatch"
        );

        address strategy = vm.parseJsonAddress(json, ".virtualLBP");
        assertEq(IContinuousClearingAuction(auction).fundsRecipient(), strategy, "Funds recipient mismatch");
        assertEq(
            IVirtualLBPStrategyBasic(payable(strategy)).operator(),
            vm.parseJsonAddress(json, ".auctionOperatorAddress"),
            "Operator mismatch"
        );

        // @note Important: Otherwise will receive an ATP
        address virtualToken = vm.parseJsonAddress(json, ".virtualAztecToken");
        assertEq(
            VirtualAztecToken(virtualToken).FOUNDATION_ADDRESS(), IContinuousClearingAuction(auction).tokensRecipient()
        );
    }

    function writeDeploymentFile() public {
        string memory chainId = vm.toString(block.chainid);
        // Always write to contracts/deployments/ (inside foundry project root)
        // The bootstrap script will copy this to the correct location
        string memory deploymentsDir = vm.envString("DEPLOYMENTS_DIR");
        if (!vm.exists(deploymentsDir)) {
            vm.createDir(deploymentsDir, true);
        }
        string memory outputPath = string.concat(deploymentsDir, "/collective-l1-deployment-", chainId, ".json");

        string memory main = "main";

        vm.serializeAddress(main, "deployerAddress", WALLETS.deployer);
        vm.serializeAddress(main, "tokenOwnerAddress", WALLETS.tokenOwner);
        vm.serializeAddress(main, "genesisSaleOwnerAddress", WALLETS.genesisSaleOwner);
        vm.serializeAddress(main, "twapTokenRecipientAddress", WALLETS.twapTokenRecipient);
        vm.serializeAddress(main, "auctionOperatorAddress", WALLETS.auctionOperator);
        vm.serializeAddress(main, "lowValueOwnerAddress", WALLETS.lowValueOwner);

        // Aztec L1 contracts
        vm.serializeAddress(main, "feeAssetAddress", address(aztec.FEE_ASSET_CONTRACT()));
        vm.serializeAddress(main, "stakingAssetAddress", address(aztec.STAKING_ASSET_CONTRACT()));
        vm.serializeAddress(main, "gseAddress", address(aztec.GSE_CONTRACT()));
        vm.serializeAddress(main, "registryAddress", address(aztec.REGISTRY_CONTRACT()));
        vm.serializeAddress(main, "rewardDistributorAddress", address(aztec.REWARD_DISTRIBUTOR_CONTRACT()));
        vm.serializeAddress(main, "governanceProposerAddress", address(aztec.GOVERNANCE_PROPOSER_CONTRACT()));
        vm.serializeAddress(main, "governanceAddress", address(aztec.GOVERNANCE_CONTRACT()));
        vm.serializeAddress(main, "coinIssuerAddress", address(aztec.COIN_ISSUER_CONTRACT()));
        vm.serializeAddress(main, "protocolTreasuryAddress", address(aztec.PROTOCOL_TREASURY_CONTRACT()));
        vm.serializeAddress(main, "flushRewarderAddress", address(aztec.FLUSH_REWARDER_CONTRACT()));
        vm.serializeAddress(main, "verifierAddress", address(aztec.VERIFIER_CONTRACT()));
        vm.serializeAddress(main, "rollupAddress", address(aztec.ROLLUP_CONTRACT()));
        vm.serializeAddress(main, "foundationPayloadAddress", address(aztec.FOUNDATION_PAYLOAD_CONTRACT()));

        // Genesis sale contracts
        DeployGenesisSaleContracts.DeployedContracts memory genesisSaleContracts = genesisSale.getDeployedContracts();
        vm.serializeAddress(main, "zkPassportVerifierAddress", genesisSaleContracts.zkPassportVerifierAddress);
        vm.serializeAddress(main, "atpFactory", genesisSaleContracts.atpFactory);
        vm.serializeAddress(main, "atpRegistry", genesisSaleContracts.atpRegistry);
        vm.serializeAddress(main, "zkPassportProvider", genesisSaleContracts.zkPassportProvider);
        vm.serializeAddress(main, "soulboundToken", genesisSaleContracts.soulboundToken);
        vm.serializeUint(main, "soulboundTokenDeploymentBlock", genesisSaleContracts.soulboundTokenDeploymentBlock);
        vm.serializeAddress(main, "genesisSequencerSale", genesisSaleContracts.genesisSequencerSale);
        vm.serializeAddress(main, "splitsWarehouse", genesisSaleContracts.splitsWarehouse);
        vm.serializeAddress(main, "pullSplitFactory", genesisSaleContracts.pullSplitFactory);
        vm.serializeAddress(main, "stakingRegistry", genesisSaleContracts.stakingRegistry);
        vm.serializeAddress(main, "predicateSanctionsProvider", genesisSaleContracts.predicateSanctionsProvider);
        vm.serializeAddress(main, "predicateKYCProvider", genesisSaleContracts.predicateKYCProvider);
        vm.serializeAddress(main, "predicateSanctionsProviderSale", genesisSaleContracts.predicateSanctionsProviderSale);
        vm.serializeAddress(
            main, "atpWithdrawableAndClaimableStaker", genesisSaleContracts.atpWithdrawableAndClaimableStaker
        );

        // Foundation actions
        vm.serializeAddress(main, "foundationActionsTarget0", foundationActionsStored.targets[0]);
        vm.serializeBytes(main, "foundationActionsData0", foundationActionsStored.datas[0]);
        vm.serializeAddress(main, "foundationActionsTarget1", foundationActionsStored.targets[1]);
        vm.serializeBytes(main, "foundationActionsData1", foundationActionsStored.datas[1]);

        // Twap contracts
        DeployAuction.DeployedAuctionContracts memory twapContracts = twap.getDeployedContracts();

        vm.serializeAddress(main, "auctionFactory", twapContracts.auctionFactory);
        vm.serializeAddress(main, "auctionHook", twapContracts.auctionHook);
        vm.serializeAddress(main, "predicateAuctionScreeningProvider", twapContracts.predicateAuctionScreeningProvider);
        vm.serializeAddress(main, "atpFactoryAuction", twapContracts.atpFactoryAuction);
        vm.serializeAddress(main, "atpRegistryAuction", twapContracts.atpRegistryAuction);
        vm.serializeAddress(main, "virtualAztecToken", twapContracts.virtualAztecToken);
        vm.serializeAddress(main, "twapAuction", twapContracts.auction);
        vm.serializeAddress(main, "tokenLauncher", twapContracts.tokenLauncher);
        vm.serializeAddress(main, "permit2", twapContracts.permit2);
        vm.serializeAddress(main, "virtualLBPFactory", twapContracts.virtualLBPFactory);
        vm.serializeAddress(main, "virtualLBP", twapContracts.predictedVirtualLBPAddress);
        vm.serializeAddress(main, "twapDateGatedRelayer", twapContracts.dateGatedRelayerShort);
        main = vm.serializeUint(main, "startBlock", twapContracts.startBlock);

        vm.writeJson(main, outputPath);
        emit log_named_string("Wrote collective-l1-deployment file to", outputPath);
    }
}
