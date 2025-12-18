// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Tests
import {StakerTestBase} from "test/btt/staking/StakerTestBase.sol";

import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";

// Atp
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {BaseStaker} from "@atp/staker/BaseStaker.sol";

// Mocks
import {MockGSE} from "test/mocks/staking/MockGSE.sol";
import {MockRegistry} from "test/mocks/staking/MockRegistry.sol";

// Libs
import {Constants} from "src/constants.sol";
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";
import {QueueLib} from "src/staking-registry/libs/QueueLib.sol";

contract StakeWithProvider is StakerTestBase {
    uint256 public providerId;
    address public providerAdmin = makeAddr("providerAdmin");
    uint16 public providerTakeRate = 90;

    function setUp() public override {
        super.setUp();

        givenNonWithdrawableStakerIsSet();
    }

    modifier givenTheCallerIsTheOperator() {
        _;
    }

    function test_WhenTheCallerIsNotTheOperator(address _caller, address _userRewardsRecipient)
        external
        givenATPIsSetUp
    {
        // it reverts
        vm.assume(_caller != OPERATOR);

        vm.expectRevert(abi.encodeWithSelector(BaseStaker.NotOperator.selector, _caller, OPERATOR));
        vm.prank(_caller);
        IATPNonWithdrawableStaker(address(staker)).stakeWithProvider(0, 0, 0, _userRewardsRecipient, true);
    }

    function test_WhenTheRollupVersionDoesNotExist(uint256 _version, address _userRewardsRecipient)
        external
        givenATPIsSetUp
        givenTheCallerIsTheOperator
    {
        vm.assume(_version != rollupRegistry.currentVersion());

        // it reverts
        vm.expectRevert(abi.encodeWithSelector(MockRegistry.InvalidRollupVersion.selector, _version));
        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker))
            .stakeWithProvider(_version, 0, providerTakeRate, _userRewardsRecipient, true);
    }

    function test_WhenTheProviderIdDoesNotExist(uint256 _providerId, address _userRewardsRecipient)
        external
        givenATPIsSetUp
        givenTheCallerIsTheOperator
    {
        // it reverts

        vm.expectRevert(
            abi.encodeWithSelector(IStakingRegistry.StakingRegistry__InvalidProviderIdentifier.selector, _providerId)
        );
        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker))
            .stakeWithProvider(0, _providerId, providerTakeRate, _userRewardsRecipient, true);
    }

    modifier givenThatAProviderIsRegistered() {
        providerId = stakingRegistry.registerProvider(providerAdmin, providerTakeRate, providerAdmin);
        _;
    }

    function test_WhenTheProviderHasNoAttestersRegistered(address _userRewardsRecipient)
        external
        givenATPIsSetUp
        givenTheCallerIsTheOperator
        givenThatAProviderIsRegistered
    {
        // it reverts
        vm.assume(_userRewardsRecipient != address(0));

        vm.expectRevert(abi.encodeWithSelector(QueueLib.QueueIsEmpty.selector));
        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker))
            .stakeWithProvider(0, providerId, providerTakeRate, _userRewardsRecipient, true);
    }

    function test_WhenTheUserRewardsRecipientIsTheZeroAddress(address _attester)
        external
        givenATPIsSetUp
        givenTheCallerIsTheOperator
        givenThatAProviderIsRegistered
    {
        // it reverts

        IStakingRegistry.KeyStore[] memory providerKeys = new IStakingRegistry.KeyStore[](1);
        providerKeys[0] = IStakingRegistry.KeyStore({
            attester: _attester,
            publicKeyG1: BN254Lib.G1Point({x: 0, y: 0}),
            publicKeyG2: BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
            proofOfPossession: BN254Lib.G1Point({x: 0, y: 0})
        });

        vm.prank(providerAdmin);
        stakingRegistry.addKeysToProvider(providerId, providerKeys);

        vm.expectRevert(abi.encodeWithSelector(IStakingRegistry.StakingRegistry__ZeroAddress.selector));
        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).stakeWithProvider(0, providerId, providerTakeRate, address(0), true);
    }

    function test_WhenTheProviderTakeRateHasChanged(
        address _attester,
        address _userRewardsRecipient,
        uint16 _newProviderTakeRate
    ) external givenATPIsSetUp givenTheCallerIsTheOperator givenThatAProviderIsRegistered {
        vm.assume(_attester != address(0));
        vm.assume(_userRewardsRecipient != address(0));
        _newProviderTakeRate = uint16(bound(_newProviderTakeRate, 0, Constants.BIPS));
        vm.assume(_newProviderTakeRate != providerTakeRate);

        IStakingRegistry.KeyStore[] memory providerKeys = new IStakingRegistry.KeyStore[](1);
        providerKeys[0] = IStakingRegistry.KeyStore({
            attester: _attester,
            publicKeyG1: BN254Lib.G1Point({x: 0, y: 0}),
            publicKeyG2: BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
            proofOfPossession: BN254Lib.G1Point({x: 0, y: 0})
        });

        vm.prank(providerAdmin);
        stakingRegistry.addKeysToProvider(providerId, providerKeys);

        vm.prank(providerAdmin);
        stakingRegistry.updateProviderTakeRate(providerId, _newProviderTakeRate);

        vm.expectRevert(
            abi.encodeWithSelector(
                IStakingRegistry.StakingRegistry__UnexpectedTakeRate.selector, providerTakeRate, _newProviderTakeRate
            )
        );
        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker))
            .stakeWithProvider(0, providerId, providerTakeRate, _userRewardsRecipient, true);
    }

    function test_GivenThatAnAttesterIsRegistered(address _attester, address _userRewardsRecipient)
        external
        givenATPIsSetUp
        givenTheCallerIsTheOperator
        givenThatAProviderIsRegistered
    {
        // it deposits into the rollup with the attester
        // it deploys a splits contract with the expected stake rate
        // it sets the staker as the withdrawer

        vm.assume(_attester != address(0));
        vm.assume(_userRewardsRecipient != address(0));

        IStakingRegistry.KeyStore[] memory providerKeys = new IStakingRegistry.KeyStore[](1);
        providerKeys[0] = IStakingRegistry.KeyStore({
            attester: _attester,
            publicKeyG1: BN254Lib.G1Point({x: 0, y: 0}),
            publicKeyG2: BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
            proofOfPossession: BN254Lib.G1Point({x: 0, y: 0})
        });

        vm.prank(providerAdmin);
        stakingRegistry.addKeysToProvider(providerId, providerKeys);

        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker))
            .stakeWithProvider(0, providerId, providerTakeRate, _userRewardsRecipient, true);

        // Note: testing the mock rollup here - not the real one - but it functions the same way
        assertEq(rollup.withdrawers(_attester), address(staker));
        assertEq(rollup.staked(_attester), rollup.getActivationThreshold());
        assertEq(rollup.isStaked(_attester), true);
        assertEq(rollup.isExiting(_attester), false);
    }
}
