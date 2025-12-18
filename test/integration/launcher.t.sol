// pragma solidity ^0.8.0;

// // internal
// import {AztecAuctionHook} from "src/uniswap-periphery/AuctionHook.sol";

// // atps
// import {ATPFactoryNonces, IATPFactoryNonces} from "@atp/ATPFactoryNonces.sol";
// import {IATPFactory} from "@atp/ATPFactory.sol";

// import {RevokableParams} from "@atp/atps/linear/ILATP.sol";
// import {LockLib} from "@atp/libraries/LockLib.sol";

// // zkPassport
// import {ProofVerificationParams} from "@zkpassport/Types.sol";

// // Predicate
// import {PredicateMessage} from "@predicate/interfaces/IPredicateClient.sol";

// // Contracts - soulbound
// import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
// // Contracts - Providers
// import {MockTrueWhitelistProvider} from "test/mocks/MockWhitelistProvider.sol";

// // perp
// import {VirtualAztecToken} from "src/uniswap-periphery/VirtualAztecToken.sol";

// // launcher
// import {TokenLauncher} from "@launcher/TokenLauncher.sol";
// import {IPoolManager} from "@v4c/interfaces/IPoolManager.sol";
// import {MigratorParameters} from "@launcher/distributionContracts/LBPStrategyBasic.sol";
// import {Distribution} from "@launcher/types/Distribution.sol";
// import {IAllowanceTransfer} from "@launcher/Permit2Forwarder.sol";
// import {IDistributionContract} from "@launcher/interfaces/IDistributionContract.sol";
// // modified launcher
// import {VirtualLBPStrategyFactory} from "@launcher/distributionStrategies/VirtualLBPStrategyFactory.sol";

// // auction
// import {IntegrationTestBase} from "test/integration/staking-aligned-participant/IntegrationTestBase.sol";
// import {AuctionStepsBuilder} from "@twap-auction-test/utils/AuctionStepsBuilder.sol";
// import {AuctionParameters} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";
// import {FixedPoint96} from "@twap-auction/libraries/FixedPoint96.sol";
// import {ContinuousClearingAuctionFactory} from "@twap-auction/ContinuousClearingAuctionFactory.sol";
// import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";

// // v4
// import {IPositionManager} from "@v4p/interfaces/IPositionManager.sol";
// import {VirtualLBPStrategyBasic} from "@launcher/distributionContracts/VirtualLBPStrategyBasic.sol";
// import {ActionConstants} from "@v4p/libraries/ActionConstants.sol";

// // oz
// import {IERC20} from "@oz/token/ERC20/IERC20.sol";

// // other
// import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

// // address generator
// import {SaltGenerator} from "./LauncherSaltGenerator.sol";

// import {console} from "forge-std/console.sol";

// interface ERC20Mintable {
//     function mint(address to, uint256 amount) external;
// }

// contract LauncherE2ETest is IntegrationTestBase {
//     using AuctionStepsBuilder for bytes;
//     using FixedPointMathLib for uint128;

//     VirtualAztecToken public virtualAztecToken;
//     AztecAuctionHook public auctionHook;

//     VirtualLBPStrategyBasic public virtualLBP;
//     AuctionParameters public auctionParams;
//     MigratorParameters public migratorParams;

//     IContinuousClearingAuction deployedAuction;

//     ATPFactoryNonces public atpFactoryAuction;

//     // ContinuousClearingAuction constants
//     uint256 public constant AUCTION_FLOOR_PRICE = (25 << FixedPoint96.RESOLUTION) / 1000000; // 0.000025
//     uint256 public constant AUCTION_TICK_SPACING = (25 << FixedPoint96.RESOLUTION) / 1000000; // 0.000025

//     int24 public constant POOL_TICK_SPACING = 6;
//     uint24 public constant TOKENS_SPLIT_TO_AUCTION = 750000; // 75%

//     uint256 public auctionDuration;

//     uint256 public START_BLOCK;
//     uint256 public constant CONTRIBUTOR_PERIOD_BLOCK_END_DELTA = 100;

//     uint256 public constant NUMBER_OF_BLOCKS_AFTER_AUCTION_FOR_MIGRATION = 1000;

//     uint128 public constant TOTAL_SUPPLY = 3_000_000e18; // 2,000,000 tokens

//     address public GOVERNANCE_ADDRESS = address(0xdeadbeef);

//     // MAINNET ADDRESSES
//     address constant POSITION_MANAGER = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
//     address constant POOL_MANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;
//     address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
//     address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

//     // Before Initialize + Before Swap
//     address public constant POOL_MASK = 0x0000000000000000000000000000000000002080;

//     function setUp() public override {
//         super.setUp();

//         START_BLOCK = block.number + 10;

//         // Deploy atp factories for virtual token
//         atpFactoryAuction = new ATPFactoryNonces(address(this), IERC20(address(stakingAsset)), 100, 100);
//         vm.label(address(atpFactoryAuction), "atpFactoryAuction");

//         // Deploy auction virtual tokens
//         virtualAztecToken =
//             new VirtualAztecToken("", "", IERC20(address(stakingAsset)), atpFactoryAuction, FOUNDATION_ADDRESS);

//         // Set the virtual Aztec Token as minter of the atps
//         atpFactoryAuction.setMinter(address(virtualAztecToken), true);

//         // Deploy auction hook
//         auctionHook = new AztecAuctionHook(soulboundToken, START_BLOCK + CONTRIBUTOR_PERIOD_BLOCK_END_DELTA);

//         bytes memory auctionStepsData = AuctionStepsBuilder.init().addStep(0, 1800) // 0 supply for 0.25 days (1800 blocks)
//             .addStep(300_000, 1) // 3% in one block
//             .addStep(0, 1800) // 0 supply for 0.25 days (1800 blocks)
//             .addStep(1_000_000, 1) // 10% in one block
//             .addStep(0, 1800) // 0 supply for 0.25 days (1800 blocks)
//             .addStep(2_000_000, 1) // 20% in one block
//             .addStep(0, 1800) // 0 supply for 0.25 days (1800 blocks)
//             .addStep(2_000_000, 1) // 20% in one block
//             .addStep(0, 1800) // 0 supply for 0.25 days (1800 blocks)
//             .addStep(2_000_000, 1) // 20% in one block
//             .addStep(0, 1800) // 0 supply for 0.25 days (1800 blocks)
//             .addStep(2_700_000, 1); // 27% in one block

//         auctionDuration = (1800 + 1) * 6;

//         auctionParams = AuctionParameters({
//             currency: address(0),
//             tokensRecipient: address(FOUNDATION_ADDRESS),
//             fundsRecipient: address(ActionConstants.MSG_SENDER), // this will set the deployer as the funds recipient - which should be the strategy
//             startBlock: uint64(START_BLOCK),
//             endBlock: uint64(START_BLOCK + auctionDuration),
//             claimBlock: uint64(START_BLOCK + auctionDuration),
//             requiredCurrencyRaised: 0,
//             tickSpacing: AUCTION_TICK_SPACING,
//             validationHook: address(auctionHook),
//             floorPrice: AUCTION_FLOOR_PRICE,
//             auctionStepsData: auctionStepsData
//         });

//         // Deploy the factory
//         VirtualLBPStrategyFactory virtualLBPFactory =
//             new VirtualLBPStrategyFactory(IPositionManager(POSITION_MANAGER), IPoolManager(POOL_MANAGER));

//         // Deploy the acution factory
//         ContinuousClearingAuctionFactory auctionFactory = new ContinuousClearingAuctionFactory();

//         // Pool tick spacing
//         migratorParams = MigratorParameters({
//             currency: address(0),
//             poolLPFee: 500,
//             poolTickSpacing: int24(POOL_TICK_SPACING),
//             tokenSplitToAuction: uint24(TOKENS_SPLIT_TO_AUCTION),
//             auctionFactory: address(auctionFactory),
//             positionRecipient: address(GOVERNANCE_ADDRESS),
//             migrationBlock: uint64(START_BLOCK + auctionDuration + NUMBER_OF_BLOCKS_AFTER_AUCTION_FOR_MIGRATION),
//             sweepBlock: uint64(START_BLOCK + auctionDuration + NUMBER_OF_BLOCKS_AFTER_AUCTION_FOR_MIGRATION + 1),
//             // TODO: who is the operator??
//             operator: address(FOUNDATION_ADDRESS),
//             // We will not be making dual sided positions
//             createOneSidedTokenPosition: false,
//             createOneSidedCurrencyPosition: false
//         });

//         // Deploy the token launcher
//         TokenLauncher tokenLauncher = new TokenLauncher(IAllowanceTransfer(PERMIT2));

//         // Deploy strategy factory
//         Distribution memory distributionParams = Distribution({
//             strategy: address(virtualLBPFactory),
//             amount: TOTAL_SUPPLY,
//             // NOTE: modified to include the govnernace address in the distribution params
//             // auctionParams are expected as bytes, so must be encoded twice
//             configData: abi.encode(GOVERNANCE_ADDRESS, migratorParams, abi.encode(auctionParams))
//         });

//         // Create the strategy
//         bytes32 initCodeHash = keccak256(
//             abi.encodePacked(
//                 type(VirtualLBPStrategyBasic).creationCode,
//                 abi.encode(
//                     virtualAztecToken,
//                     uint128(TOTAL_SUPPLY),
//                     migratorParams,
//                     abi.encode(auctionParams),
//                     POSITION_MANAGER,
//                     POOL_MANAGER,
//                     GOVERNANCE_ADDRESS
//                 )
//             )
//         );

//         // Mined using https://github.com/AztecProtocol/token-launcher-address-miner
//         address poolMask = address(POOL_MASK);
//         bytes32 generatedSalt = new SaltGenerator().withInitCodeHash(initCodeHash).withMask(poolMask)
//             .withMsgSender(address(this)).withTokenLauncher(address(tokenLauncher))
//             .withStrategyFactoryAddress(address(virtualLBPFactory)).generate();

//         // Collateralise the virtual token
//         ERC20Mintable(address(stakingAsset)).mint(address(this), TOTAL_SUPPLY);
//         stakingAsset.approve(address(virtualAztecToken), TOTAL_SUPPLY);

//         // Send the tokens to the token launcher such that it can mint
//         // Concern: front running risk exists - we want this to be atomic
//         // TODO: is there a way to do it with permit2 to prevent frontrunning
//         // - yes there is - we need to explicitly approve the to address to be the predicted distributioncontract
//         // - address - therefore even if frontrun they will create the exact same strategy that you intended to
//         ERC20Mintable(address(virtualAztecToken)).mint(address(tokenLauncher), TOTAL_SUPPLY);

//         // predict the strategy address
//         address predictedVirtualLBPAddress = virtualLBPFactory.getVirtualLBPAddress(
//             address(virtualAztecToken),
//             TOTAL_SUPPLY,
//             distributionParams.configData,
//             keccak256(abi.encode(address(this), generatedSalt)),
//             address(tokenLauncher)
//         );

//         // Predict the auction address
//         AuctionParameters memory auctionParamsMem = auctionParams;
//         // the auction constants will cause the recipient to be modified to an address that is the deployed strategy address
//         auctionParamsMem.fundsRecipient = predictedVirtualLBPAddress;

//         // total supply is the prorata based on the tokens split to auction
//         // Calculting auction supply as reserve supply first as this is how the launcher does it
//         uint256 reserveSupply = TOTAL_SUPPLY - (TOTAL_SUPPLY * TOKENS_SPLIT_TO_AUCTION / 1e7);
//         uint256 auctionSupply = TOTAL_SUPPLY - reserveSupply;

//         deployedAuction = IContinuousClearingAuction(
//             auctionFactory.getAuctionAddress(
//                 address(virtualAztecToken),
//                 auctionSupply,
//                 abi.encode(auctionParamsMem),
//                 bytes32(0),
//                 predictedVirtualLBPAddress // sender will be the dsitribution contract
//             )
//         );

//         auctionHook.setAuction(deployedAuction);

//         // Set the strategy and auction address on the virtual token
//         virtualAztecToken.setAuctionAddress(IContinuousClearingAuction(deployedAuction));
//         virtualAztecToken.setStrategyAddress(predictedVirtualLBPAddress);

//         // Deploy the strategy and auction
//         virtualLBP = VirtualLBPStrategyBasic(
//             payable(address(
//                     tokenLauncher.distributeToken(
//                         address(virtualAztecToken), distributionParams, false, bytes32(uint256(generatedSalt))
//                     )
//                 ))
//         );
//         assert(address(virtualLBP) != address(0));

//         // If these addresses are not the same, then the address the virtual aztec token has has its strategy address is
//         // incorrect
//         assertEq(predictedVirtualLBPAddress, address(virtualLBP));

//         // TODO: use real predicate screening provider
//         address auctionHookMockTrueScreeningProvider = address(new MockTrueWhitelistProvider());
//         virtualAztecToken.setScreeningProvider(auctionHookMockTrueScreeningProvider);

//         vm.label(address(virtualLBP), "virtualLBP");
//     }

//     function test_launcher() public {
//         if (block.chainid == 31337) {
//             // TODO: propoer fork setup
//             return;
//             // revert("Not without a mainnet fork");
//         }
//         // At this point we should have an auction which we can send bids to
//         // Assert that all of the correct amounts of the virtual token are within the acution
//         // whenever the auction concludes we need the correct number of virtual token to be sent to the right places and we need the real tokens to be sent into the pool which graduates

//         // Go to the start of the acution
//         vm.roll(auctionParams.startBlock + 1);

//         address bidder = makeAddr("bidder");

//         // Mint the sender the compliance token
//         // - do this on mainnet to mint the compliance token
//         {
//             soulboundToken.adminMint(bidder, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, 1);
//         }
//         // Real minting of the compliance token using zkpassport fixture - note this does not work on mainnet fork as the
//         // proof is bound to a network
//         // {
//         //     uint256 gridTileId = 1;
//         //
//         //     bytes32[] memory merkleProof = new bytes32[](0);
//         //     ProofVerificationParams memory zkPassportParams = makeValidProof();
//         //     PredicateMessage memory screeningAttestation = makeSoulboundPredicateAttestation();
//         //
//         //     vm.expectEmit(true, true, true, true, address(soulboundToken));
//         //     emit IIgnitionParticipantSoulbound.IgnitionParticipantSoulboundMinted(
//         //         bidder, participant, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, gridTileId
//         //     );
//         //     vm.prank(participant);
//         //     soulboundToken.mint(
//         //         IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
//         //         bidder,
//         //         merkleProof,
//         //         address(zkPassportWhitelistProvider),
//         //         abi.encode(zkPassportParams),
//         //         abi.encode(screeningAttestation),
//         //         gridTileId
//         //     );
//         // }

//         // Send a bid for the total supply at the tick above the floor price
//         uint256 bidId;
//         {
//             // For now floor price is a multiple of the tick price so we can use multiples of it for the correct tick values
//             // Place a bid that will clear the entire supply of the tokens
//             uint256 bidMaxPrice = 2 * AUCTION_FLOOR_PRICE;
//             // We bid for the whole shebang
//             uint128 bidAmount = getAmountRequiredToPurchaseTokens(1e12 ether, bidMaxPrice);

//             // Arbitrarily large war chest
//             vm.deal(bidder, 1e12 ether);
//             vm.prank(bidder);
//             bidId = deployedAuction.submitBid{value: bidAmount}(
//                 bidMaxPrice, // maxPrice
//                 bidAmount, // amount
//                 bidder, // owner
//                 AUCTION_FLOOR_PRICE, // tick lower
//                 "" // hook data - mock hook
//             );
//         }

//         // move forward to the end of the auction
//         vm.roll(auctionParams.claimBlock);
//         deployedAuction.checkpoint();

//         // Bid is fully filled as the bid was at clearing
//         deployedAuction.exitPartiallyFilledBid(bidId, auctionParams.startBlock + 1, 0);

//         uint256 reserveSupply = TOTAL_SUPPLY - (TOTAL_SUPPLY * TOKENS_SPLIT_TO_AUCTION / 1e7);
//         uint256 auctionSupply = TOTAL_SUPPLY - reserveSupply;

//         // Note: this is as we have bid for the whole shebango
//         uint256 expectedAllocation = auctionSupply;

//         // Claim my bid
//         RevokableParams memory emptyRevokableParams =
//             RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()});
//         address predictedLATPAddress =
//             atpFactoryAuction.predictLATPAddress(bidder, expectedAllocation, emptyRevokableParams);

//         deployedAuction.claimTokens(bidId);

//         vm.expectEmit(true, true, true, true, address(atpFactoryAuction));
//         emit IATPFactory.ATPCreated(address(bidder), predictedLATPAddress, expectedAllocation);
//         vm.prank(bidder);
//         virtualAztecToken.sweepIntoAtp();

//         // Claim the unsold tokens
//         {
//             uint256 expectedSweepedTokens = auctionSupply - expectedAllocation;

//             uint256 foundationVirtualTokenBalanceBefore = virtualAztecToken.balanceOf(FOUNDATION_ADDRESS);
//             uint256 foundationAztecTokenBalanceBefore = stakingAsset.balanceOf(FOUNDATION_ADDRESS);

//             // Should have no balances before
//             assertEq(foundationAztecTokenBalanceBefore, 0);
//             assertEq(foundationVirtualTokenBalanceBefore, 0);

//             vm.prank(FOUNDATION_ADDRESS);
//             deployedAuction.sweepUnsoldTokens();

//             uint256 foundationVirtualTokenBalanceAfter = virtualAztecToken.balanceOf(FOUNDATION_ADDRESS);
//             uint256 foundationAztecTokenBalanceAfter = stakingAsset.balanceOf(FOUNDATION_ADDRESS);

//             // We should not get any virtual aztec tokens
//             assertEq(foundationVirtualTokenBalanceAfter, 0);
//             // We should get the remaining underlying aztec tokens
//             // NOTE: there is dust of 1 wei left in the contract in happy paths so might need to change this line
//             assertEq(foundationAztecTokenBalanceAfter, expectedSweepedTokens);
//         }

//         // Claim the raised currency
//         // NOTE: the raised currency here does to the strategy contract
//         // - we need to be able to call the migrate functions on the strategy before progressing to pool creation
//         // TODO(md): add the expected values after updating to the new version of the auction
//         {
//             uint256 distributionEthBalanceBefore = address(virtualLBP).balance;
//             vm.prank(FOUNDATION_ADDRESS);
//             deployedAuction.sweepCurrency();

//             uint256 distributionContractEthBalanceAfter = address(virtualLBP).balance;
//             // TODO(md): THIS IS WRONG DUE TO USING OLD AUCTION VERSION - IT SHOULD BE 200 ether
//             // TODO: update
//             // assertEq(distributionContractEthBalanceAfter, distributionEthBalanceBefore  + 0.01 ether);
//         }

//         // Migrate the auction to the uniswap pool
//         // I guess this can be run against a mainnet fork for the liquidity pool to be created

//         vm.roll(migratorParams.migrationBlock);

//         // TODO(md): assert for all of the correct event migration values
//         // First expect migration to fail as the migration has not been approved by govnerance
//         vm.expectRevert(abi.encodeWithSignature("MigrationNotApproved()"));
//         virtualLBP.migrate();

//         // Approve the migration from governance
//         vm.prank(GOVERNANCE_ADDRESS);
//         virtualLBP.approveMigration();

//         // Re attempt to perform the migration
//         virtualLBP.migrate();

//         // TODO: it did not seem like we managed to stop creation of the pool by not having governance do something first
//         // also there is no way that we had enough liquidity paired with this thing

//         // Now the pool has been created we should be able to swap for the main tokens

//         // Can the foundation get the raised currency back even if the migration has not happened yet?
//         // Or do they have to wait until the pool is created for this to work?
//     }

//     // Other tests
//     // What happens in the case that we do not raise enough tokens in the end
//     // What happens in the bid refund and graduation case

//     // TODO: add to a lib
//     function getAmountRequiredToPurchaseTokens(uint128 numTokens, uint256 maxPrice) internal pure returns (uint128) {
//         return uint128(numTokens.fullMulDivUp(maxPrice, FixedPoint96.Q96));
//     }
// }
