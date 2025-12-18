// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Contracts - Soulbound
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {IPredicateProvider} from "src/soulbound/providers/PredicateProvider.sol";
import {PredicateMessage} from "@predicate/interfaces/IPredicateClient.sol";

// Contracts - Sale
import {GenesisSequencerSale} from "src/sale/GenesisSequencerSale.sol";
import {IGenesisSequencerSale} from "src/sale/IGenesisSequencerSale.sol";

// Contracts - ATP
import {ATPFactory, Registry, IRegistry} from "@atp/ATPFactory.sol";
import {ILATP} from "@atp/atps/linear/ILATP.sol";
import {IATPCore} from "@atp/atps/base/IATP.sol";
import {ATPNonWithdrawableStaker} from "src/staking/ATPNonWithdrawableStaker.sol";
import {StakerVersion} from "@atp/Registry.sol";
import {RevokableParams} from "@atp/atps/linear/ILATP.sol";
import {LockLib} from "@atp/libraries/LockLib.sol";

// Contracts - ATP Staking
import {ATPNonWithdrawableStaker} from "src/staking/ATPNonWithdrawableStaker.sol";
import {ATPWithdrawableStaker} from "src/staking/ATPWithdrawableStaker.sol";
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {IATPWithdrawableStaker} from "src/staking/interfaces/IATPWithdrawableStaker.sol";

// Contracts - Staking Registry
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {StakingRegistry} from "src/staking-registry/StakingRegistry.sol";

// External contracts - Splits
import {PullSplitFactory} from "@splits/splitters/pull/PullSplitFactory.sol";

import {Errors} from "@oz/utils/Errors.sol";

import {ProofVerificationParams} from "@zkpassport/Types.sol";

import {IntegrationTestBase} from "./IntegrationTestBase.sol";

// Libraries
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

/**
 * @title Staking Aligned Participant Integration Test
 *
 * End to end test of the staking aligned participant flow - covering
 * - Soulbound token claim
 * - Purchase of ATPs
 * - Registering stakers
 * - Staking with the rollup
 * - Staking with a provider (through the registry)
 *
 * User journey:
 * - Claim soulbound token using zk passport
 * - Puchase two ATPs
 *  - One containing 2 lots of the staking asset
 *  - One containing 3 lots of the staking asset
 * - Register the stakers
 * - Stake with the rollup
 * - Stake with a provider (through the registry)
 * - Withdraw the funds from the ATPs
 * - Claim the rewards from the provider - TODO
 */
contract StakingAlignedParticipantTest is IntegrationTestBase {
    // function help__predictSplitAddresses(uint256 _tokenLotSize) public view returns (address, address, address) {
    //     address[] memory recipients = new address[](2);
    //     recipients[0] = makeAddr("providerRewardsRecipient");
    //     recipients[1] = makeAddr("rewardsRecipient");

    //     uint256[] memory allocations = new uint256[](2);
    //     allocations[0] = 10;
    //     allocations[1] = 90;

    //     return PullSplitFactory(address(pullSplitFactory)).predictSplitAddress(recipients, allocations, _tokenLotSize);
    // }

    address public SOULBOUND_BENEFICIARY = makeAddr("soulboundBeneficiary");

    uint16 public providerOneTakeRate = 1000;
    uint16 public providerTwoTakeRate = 2000;

    uint256 public gridTileId = 1;

    function test_GoesThroughTheSale() public {
        vm.deal(participant, 100 ether); // Participant is rich
        vm.deal(SOULBOUND_BENEFICIARY, 100 ether); // Soulbound beneficiary is rich
        uint256 fiveLots = pricePerLot * genesisSequencerSale.PURCHASES_PER_ADDRESS();

        // Merkle proof is empty, as it is just one address in the tree

        // 1. Mint the soulbound token, having completed a zk passport verification
        // Note, - using mock zk passport provider for now - we can update to include the real provider and create fixtures
        // This valid proof is bound to the participant's address
        {
            bytes32[] memory merkleProof = new bytes32[](0);
            ProofVerificationParams memory zkPassportParams = makeValidProof();
            PredicateMessage memory screeningAttestation = makeSoulboundPredicateAttestation();

            vm.expectEmit(true, true, true, true, address(soulboundToken));
            emit IIgnitionParticipantSoulbound.IgnitionParticipantSoulboundMinted(
                SOULBOUND_BENEFICIARY, participant, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, gridTileId
            );
            vm.prank(participant);
            soulboundToken.mint(
                IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
                SOULBOUND_BENEFICIARY,
                merkleProof,
                address(zkPassportWhitelistProvider),
                abi.encode(zkPassportParams),
                abi.encode(screeningAttestation),
                gridTileId
            );

            assertEq(
                soulboundToken.balanceOf(
                    SOULBOUND_BENEFICIARY, uint256(IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER)
                ),
                1
            );

            // Set the sale to be active
            vm.warp(block.timestamp + 1 days + 1);
            vm.expectEmit(true, true, true, true, address(genesisSequencerSale));
            emit IGenesisSequencerSale.SaleStarted(SALE_START_TIME, SALE_END_TIME);
            genesisSequencerSale.startSale();
        }

        address atpAddress;
        {
            atpAddress = atpFactory.predictNCATPAddress(
                participant,
                genesisSequencerSale.SALE_TOKEN_PURCHASE_AMOUNT(),
                RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
            );
        }

        // There should be one ATPs minted
        {
            PredicateMessage memory screeningAttestation = makeSalePredicateAttestation();

            uint256 purchaseCostInEth = genesisSequencerSale.getPurchaseCostInEth();
            assertEq(
                soulboundToken.balanceOf(
                    SOULBOUND_BENEFICIARY, uint256(IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER)
                ),
                1
            );
            // 2. Participant purchases
            vm.expectEmit(true, true, true, true, address(genesisSequencerSale));
            emit IGenesisSequencerSale.SaleTokensPurchased(
                participant, SOULBOUND_BENEFICIARY, atpAddress, purchaseCostInEth
            );
            vm.prank(SOULBOUND_BENEFICIARY);
            genesisSequencerSale.purchase{value: purchaseCostInEth}(participant, abi.encode(screeningAttestation));
        }

        // Prepare the ATP registry for this lot to enable staking
        {
            Registry registry = Registry(address(atpFactory.getRegistry()));
            vm.expectEmit(true, true, true, true, address(registry));
            emit IRegistry.StakerRegistered(StakerVersion.wrap(1), address(atpNonWithdrawableStaker));
            vm.prank(FOUNDATION_ADDRESS);
            registry.registerStakerImplementation(address(atpNonWithdrawableStaker));
        }

        // For the first atp - we set the operator to be the participants address
        {
            vm.expectEmit(true, true, true, true, address(atpAddress));
            emit IATPCore.StakerOperatorUpdated(participant);
            vm.prank(participant);
            ILATP(atpAddress).updateStakerOperator(participant);

            // Update both to the new staker implementation
            vm.expectEmit(true, true, true, true, address(atpAddress));
            emit IATPCore.StakerUpgraded(StakerVersion.wrap(1));
            vm.prank(participant);
            ILATP(atpAddress).upgradeStaker(StakerVersion.wrap(1));

            // Expect revert as execution is not allowed yet
            vm.prank(participant);
            vm.expectRevert(); // TODO: update to specific revert
            ILATP(atpAddress).approveStaker(fiveLots);

            // Fast forward to the correct time period - when execution is allowed
            vm.warp(1798761600 + 1);

            // Execution allowed
            uint256 amountOfTokens =
                genesisSequencerSale.PURCHASES_PER_ADDRESS() * genesisSequencerSale.TOKEN_LOT_SIZE();
            vm.expectEmit(true, true, true, true, address(atpAddress));
            emit IATPCore.ApprovedStaker(amountOfTokens);
            vm.prank(participant);
            ILATP(atpAddress).approveStaker(amountOfTokens);
        }

        // For the second atp - we set the operator to be another address
        address selfNodeAttester = makeAddr("selfNodeAttester");
        address selfNodeAttester2 = makeAddr("selfNodeAttester2");
        {
            IATPNonWithdrawableStaker atpStaker = IATPNonWithdrawableStaker(address(ILATP(atpAddress).getStaker()));

            uint256 tokenLotSize = genesisSequencerSale.TOKEN_LOT_SIZE();

            // Staking should not be allowed until we fast forward to the correct time period

            // Note: for now using 0 keys, as we are not checking them
            BN254Lib.G1Point memory publicKeyG1 = BN254Lib.G1Point({x: 0, y: 0});
            BN254Lib.G2Point memory publicKeyG2 = BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0});
            BN254Lib.G1Point memory signature = BN254Lib.G1Point({x: 0, y: 0});

            // Deposit into rollup
            // 1. Deposit using the default flow
            // Rollup version is 1 - TODO: test with multiple versions
            vm.prank(participant);
            IATPNonWithdrawableStaker(atpStaker).stake(0, selfNodeAttester, publicKeyG1, publicKeyG2, signature, true);

            assertEq(
                stakingAsset.balanceOf(address(atpAddress)),
                tokenLotSize * 4,
                "atp should have one lot size after staking"
            );

            // Stake with another attester
            vm.prank(participant);
            IATPNonWithdrawableStaker(atpStaker).stake(0, selfNodeAttester2, publicKeyG1, publicKeyG2, signature, true);

            assertEq(
                stakingAsset.balanceOf(address(atpAddress)),
                tokenLotSize * 3,
                "atp should have 3 lots tokens after staking"
            );

            IStakingRegistry.KeyStore memory providerAttester = makeKeyStore("providerAttester");
            IStakingRegistry.KeyStore memory providerAttester2 = makeKeyStore("providerAttester2");
            IStakingRegistry.KeyStore memory provider2Attester = makeKeyStore("provider2Attester");
            {
                {
                    address providerAdmin = makeAddr("providerAdmin");
                    address providerRewardsRecipient = makeAddr("providerRewardsRecipient");

                    // Provider comes along and registers an attester for the participant
                    // Register the provider with a 10% take rate
                    vm.prank(providerAdmin);
                    stakingRegistry.registerProvider(providerAdmin, providerOneTakeRate, providerRewardsRecipient);

                    IStakingRegistry.KeyStore[] memory providerKeys = new IStakingRegistry.KeyStore[](2);
                    providerKeys[0] = providerAttester;
                    providerKeys[1] = providerAttester2;

                    vm.prank(providerAdmin);
                    stakingRegistry.addKeysToProvider(1, providerKeys);
                }

                {
                    address providerAdmin2 = makeAddr("providerAdmin2");
                    address providerRewardsRecipient2 = makeAddr("providerRewardsRecipient2");

                    vm.prank(providerAdmin2);
                    stakingRegistry.registerProvider(providerAdmin2, providerTwoTakeRate, providerRewardsRecipient2);

                    IStakingRegistry.KeyStore[] memory providerKeys2 = new IStakingRegistry.KeyStore[](1);
                    providerKeys2[0] = provider2Attester;

                    vm.prank(providerAdmin2);
                    stakingRegistry.addKeysToProvider(2, providerKeys2);
                }

                address rewardsRecipient = makeAddr("rewardsRecipient");

                // TODO: can we predict the splits address up front - since there are nonces? make function
                // Predict the splits address for the reward split
                // address providerAttesterSplitAddress1
                // address providerAttesterSplitAddress2
                // address provider2AttesterSplitAddress

                // Lot 1. Deposit using the staking registry
                // vm.expectEmit(true, true, true, true, address(stakingRegistry));
                // emit IStakingRegistry.StakedWithProvider(1, address(rollup), providerAttester, providerAttesterSplitAddress1);
                vm.prank(participant);
                IATPNonWithdrawableStaker(atpStaker)
                    .stakeWithProvider( /*rollup version*/
                        0,
                        /*provider identifier*/
                        1,
                        providerOneTakeRate,
                        rewardsRecipient,
                        true
                    );

                // The atp2 staker should have the remaining token amount
                assertEq(
                    stakingAsset.balanceOf(address(atpAddress)),
                    tokenLotSize * 2,
                    "atp staker should have 2 lots tokens after staking with provider"
                );

                // Lot 2. Deposit again using the same provider
                // vm.expectEmit(true, true, true, true, address(stakingRegistry));
                // emit IStakingRegistry.StakedWithProvider(1, address(rollup), providerAttester, providerAttesterSplitAddress2);
                vm.prank(participant);
                IATPNonWithdrawableStaker(atpStaker)
                    .stakeWithProvider( /*rollup version*/
                        0,
                        /*provider identifier*/
                        1,
                        providerOneTakeRate,
                        rewardsRecipient,
                        true
                    );

                // The atp2 staker should have the remaining token amount
                assertEq(
                    stakingAsset.balanceOf(address(atpAddress)),
                    tokenLotSize * 1,
                    "atp staker should have 1 lots tokens after staking twice with provider"
                );

                // Lot 3. Deposit using a different provider
                // vm.expectEmit(true, true, true, true, address(stakingRegistry));
                // emit IStakingRegistry.StakedWithProvider(1, address(rollup), provider2Attester, provider2AttesterSplitAddress);
                vm.prank(participant);
                IATPNonWithdrawableStaker(atpStaker)
                    .stakeWithProvider( /*rollup version*/
                        0,
                        /*provider identifier*/
                        2,
                        providerTwoTakeRate,
                        rewardsRecipient,
                        true
                    );

                // The atp2 staker should have the remaining token amount
                assertEq(
                    stakingAsset.balanceOf(address(atpAddress)),
                    0,
                    "atp staker should have no tokens after staking its full amount with 3 attesters"
                );

                // TODO: expect staking attempt to succeed
            }

            // Register the withdrawer contract
            // Update the atps to use the withdrawer contract
            // Withdraw the funds from all of the atps
            {
                // Register the withdrawer contract
                Registry registry = Registry(address(atpFactory.getRegistry()));
                vm.expectEmit(true, true, true, true, address(registry));
                emit IRegistry.StakerRegistered(StakerVersion.wrap(2), address(atpWithdrawableStaker));
                vm.prank(FOUNDATION_ADDRESS);
                registry.registerStakerImplementation(address(atpWithdrawableStaker));

                // Update the atps to use the withdrawer contract
                vm.prank(participant);
                ILATP(atpAddress).upgradeStaker(StakerVersion.wrap(2));
            }

            assertEq(stakingAsset.balanceOf(address(rollup)), tokenLotSize * 5, "rollup should have the all tokens");

            {
                IATPWithdrawableStaker atpStaker = IATPWithdrawableStaker(address(ILATP(atpAddress).getStaker()));

                // Initiate the withdrawals
                vm.prank(participant);
                atpStaker.initiateWithdraw( /*rollup version*/
                    0,
                    selfNodeAttester
                );
                vm.prank(participant);
                atpStaker.initiateWithdraw( /*rollup version*/
                    0,
                    selfNodeAttester2
                );

                // Initiate withdrawals for the second atp
                vm.prank(participant);
                atpStaker.initiateWithdraw( /*rollup version*/
                    0,
                    providerAttester.attester
                );
                vm.prank(participant);
                atpStaker.initiateWithdraw( /*rollup version*/
                    0,
                    providerAttester2.attester
                );
                vm.prank(participant);
                atpStaker.initiateWithdraw( /*rollup version*/
                    0,
                    provider2Attester.attester
                );

                assertEq(
                    stakingAsset.balanceOf(address(atpAddress)),
                    0,
                    "atp should have no tokens after initiating withdraw"
                );
                assertEq(
                    stakingAsset.balanceOf(address(rollup)),
                    tokenLotSize * 5,
                    "rollup should have the tokens after initiating withdraw"
                );

                // finalise the withdrawals
                {
                    vm.prank(participant);
                    atpStaker.finalizeWithdraw( /*rollup version*/
                        0,
                        selfNodeAttester
                    );
                    vm.prank(participant);
                    atpStaker.finalizeWithdraw( /*rollup version*/
                        0,
                        selfNodeAttester2
                    );

                    vm.prank(participant);
                    atpStaker.finalizeWithdraw( /*rollup version*/
                        0,
                        providerAttester.attester
                    );
                    vm.prank(participant);
                    atpStaker.finalizeWithdraw( /*rollup version*/
                        0,
                        providerAttester2.attester
                    );
                    vm.prank(participant);
                    atpStaker.finalizeWithdraw( /*rollup version*/
                        0,
                        provider2Attester.attester
                    );

                    assertEq(stakingAsset.balanceOf(participant), 0);

                    // The tokens are returned to the ATP
                    assertEq(
                        stakingAsset.balanceOf(atpAddress),
                        tokenLotSize * 5,
                        "atp should have five lot sizes after finalizing withdraw"
                    );
                }
            }
        }

        // TODO: Grant rewards to be claimed by the participants
    }

    function test_FailsIfBeneficiaryAlreadyHasAnATP() public {
        // 1. Admin mints a soulbound token to 2 participants
        address participant2 = makeAddr("participant2");
        address beneficiary = makeAddr("beneficiary");
        soulboundToken.adminMint(participant, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, gridTileId++);
        soulboundToken.adminMint(participant2, IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER, gridTileId);

        vm.deal(participant, 100 ether); // Participant is rich
        vm.deal(participant2, 100 ether); // Participant 2 is rich

        // Set the sale to be active
        vm.warp(block.timestamp + 1 days + 1);
        genesisSequencerSale.startSale();

        PredicateMessage memory screeningAttestation = makeSalePredicateAttestation();

        uint256 purchaseCostInEth = genesisSequencerSale.getPurchaseCostInEth();
        vm.prank(participant);
        genesisSequencerSale.purchase{value: purchaseCostInEth}(beneficiary, abi.encode(screeningAttestation));
        vm.prank(participant2);
        vm.expectRevert(Errors.FailedDeployment.selector);
        genesisSequencerSale.purchase{value: purchaseCostInEth}(beneficiary, abi.encode(screeningAttestation));
    }
}
