// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Tests
import {StakingRegistryBase} from "test/btt/staking-registry/StakingRegistryBase.sol";

// Splits
import {PullSplitFactory} from "@splits/splitters/pull/PullSplitFactory.sol";
import {SplitFactoryV2} from "@splits/splitters/SplitFactoryV2.sol";
import {SplitV2Lib} from "@splits/libraries/SplitV2.sol";

// Atp
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";

// Mocks
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockRegistry} from "test/mocks/staking/MockRegistry.sol";

// Libs
import {Constants} from "src/constants.sol";
import {QueueLib} from "src/staking-registry/libs/QueueLib.sol";

contract Staking is StakingRegistryBase {
    uint256 public providerId;
    address public providerAdmin = makeAddr("providerAdmin");
    uint16 public providerTakeRate = 9000;

    uint256 rollupVersion = 0;

    function setUp() public override {
        super.setUp();
    }

    function test_WhenTheProviderDoesNotExist(
        uint256 _providerId,
        uint16 _expectedProviderTakeRate,
        address _withdrawalAddress,
        address _userRewardsRecipient,
        bool _moveWithLatestRollup
    ) external {
        // it reverts
        vm.expectRevert(
            abi.encodeWithSelector(IStakingRegistry.StakingRegistry__InvalidProviderIdentifier.selector, _providerId)
        );
        stakingRegistry.stake(
            _providerId,
            rollupVersion,
            _withdrawalAddress,
            _expectedProviderTakeRate,
            _userRewardsRecipient,
            _moveWithLatestRollup
        );
    }

    modifier givenTheProviderExists() {
        providerId = stakingRegistry.registerProvider(providerAdmin, providerTakeRate, providerAdmin);
        _;
    }

    function test_WhenTheProviderHasNoKeysRegistered(
        address _withdrawalAddress,
        address _userRewardsRecipient,
        bool _moveWithLatestRollup
    ) external givenTheProviderExists {
        // it reverts
        vm.assume(_withdrawalAddress != address(0));
        vm.assume(_userRewardsRecipient != address(0));

        vm.expectRevert(abi.encodeWithSelector(QueueLib.QueueIsEmpty.selector));
        stakingRegistry.stake(
            providerId,
            rollupVersion,
            _withdrawalAddress,
            providerTakeRate,
            _userRewardsRecipient,
            _moveWithLatestRollup
        );
    }

    function addKeyToProvider(address _attester) internal {
        vm.prank(providerAdmin);
        IStakingRegistry.KeyStore[] memory providerKeys = new IStakingRegistry.KeyStore[](1);
        providerKeys[0] = makeKeyStore(_attester);

        stakingRegistry.addKeysToProvider(providerId, providerKeys);
    }

    modifier givenTheProviderHasKeysRegistered() {
        addKeyToProvider(makeAddr("attester"));
        _;
    }

    // Note: there is nothing to stop this from happening, we assume this will be called via a staker
    function test_whenTheRollupVersionDoesNotExist(
        uint256 _rollupVersion,
        address _withdrawalAddress,
        address _userRewardsRecipient,
        bool _moveWithLatestRollup
    ) external givenTheProviderExists {
        // it reverts
        vm.assume(_userRewardsRecipient != address(0));
        vm.assume(_withdrawalAddress != address(0));
        vm.assume(_rollupVersion != rollupVersion);

        vm.expectRevert(abi.encodeWithSelector(MockRegistry.InvalidRollupVersion.selector, _rollupVersion));
        stakingRegistry.stake(
            providerId,
            _rollupVersion,
            _withdrawalAddress,
            providerTakeRate,
            _userRewardsRecipient,
            _moveWithLatestRollup
        );
    }

    function test_WhenTheWithdrawalAddressIsTheZeroAddress(address _userRewardsRecipient, bool _moveWithLatestRollup)
        external
        givenTheProviderExists
        givenTheProviderHasKeysRegistered
    {
        // it reverts
        vm.assume(_userRewardsRecipient != address(0));

        vm.expectRevert(abi.encodeWithSelector(IStakingRegistry.StakingRegistry__ZeroAddress.selector));
        stakingRegistry.stake(
            providerId, rollupVersion, address(0), providerTakeRate, _userRewardsRecipient, _moveWithLatestRollup
        );
    }

    function test_WhenTheUserRewardsRecipientIsTheZeroAddress(address _withdrawalAddress, bool _moveWithLatestRollup)
        external
        givenTheProviderExists
        givenTheProviderHasKeysRegistered
    {
        // it reverts
        vm.assume(_withdrawalAddress != address(0));

        vm.expectRevert(abi.encodeWithSelector(IStakingRegistry.StakingRegistry__ZeroAddress.selector));
        stakingRegistry.stake(
            providerId, rollupVersion, _withdrawalAddress, providerTakeRate, address(0), _moveWithLatestRollup
        );
    }

    // Emulating when the queue reverts and returns the funds to the withdrawal address
    function test_WhenTheDepositCallReverts(
        address _caller,
        address _withdrawalAddress,
        address _userRewardsRecipient,
        bool _moveWithLatestRollup
    ) external givenTheProviderExists givenTheProviderHasKeysRegistered {
        // it reverts
        vm.assume(_withdrawalAddress != address(0));
        vm.assume(_userRewardsRecipient != address(0));
        vm.assume(_caller != address(0));
        vm.assume(_caller != address(this));

        rollup.setShouldDepositFail(true);

        uint256 activationThreshold = rollup.getActivationThreshold();

        MockERC20(address(stakingAsset)).mint(_caller, activationThreshold);
        vm.prank(_caller);
        stakingAsset.approve(address(stakingRegistry), activationThreshold);

        vm.prank(_caller);
        stakingRegistry.stake(
            providerId,
            rollupVersion,
            _withdrawalAddress,
            providerTakeRate,
            _userRewardsRecipient,
            _moveWithLatestRollup
        );

        assertEq(stakingAsset.balanceOf(_withdrawalAddress), activationThreshold);
        if (_caller != _withdrawalAddress) {
            assertEq(stakingAsset.balanceOf(_caller), 0);
        }
    }

    function test_WhenTheProviderTakeRateHasChanged(
        address _withdrawalAddress,
        address _userRewardsRecipient,
        uint16 _newProviderTakeRate,
        bool _moveWithLatestRollup
    ) external givenTheProviderExists givenTheProviderHasKeysRegistered {
        // it reverts
        vm.assume(_withdrawalAddress != address(0));
        vm.assume(_userRewardsRecipient != address(0));
        _newProviderTakeRate = uint16(bound(_newProviderTakeRate, 0, Constants.BIPS));
        vm.assume(_newProviderTakeRate != providerTakeRate);

        vm.expectRevert(
            abi.encodeWithSelector(
                IStakingRegistry.StakingRegistry__UnexpectedTakeRate.selector, _newProviderTakeRate, providerTakeRate
            )
        );
        stakingRegistry.stake(
            providerId,
            rollupVersion,
            _withdrawalAddress,
            _newProviderTakeRate,
            _userRewardsRecipient,
            _moveWithLatestRollup
        );
    }

    // tODO:
    // function test_whenTheRollupVersionIsNotValid()  external {

    // }

    function test_WhenTheProviderHasKeysRegistered(
        address _caller,
        address _withdrawalAddress,
        address _userRewardsRecipient,
        bool _moveWithLatestRollup
    ) external givenTheProviderExists {
        // it should be able to stake
        // it should deploy a split contract
        // it should emit {StakedWithProvider} event
        // it should be split correctly
        // the recipient of the split contract should be the user and the providerReward recipient

        vm.assume(_withdrawalAddress != address(0));
        vm.assume(_withdrawalAddress != address(rollup));
        vm.assume(_userRewardsRecipient != address(0));
        vm.assume(_caller != address(0));
        vm.assume(_caller != address(this));

        address attester = makeAddr("attester");
        addKeyToProvider(attester);

        // Work out split address given we should know the nonce beforehand
        address[] memory recipients = new address[](2);
        recipients[0] = providerAdmin;
        recipients[1] = _userRewardsRecipient;

        uint256[] memory allocations = new uint256[](2);
        allocations[0] = 9000;
        allocations[1] = 1000;

        SplitV2Lib.Split memory splitParams = SplitV2Lib.Split({
            recipients: recipients, allocations: allocations, totalAllocation: Constants.BIPS, distributionIncentive: 0
        });
        address splitAddress = pullSplitFactory.predictDeterministicAddress(
            splitParams,
            /*owner=*/
            address(0)
        );

        uint256 activationThreshold = rollup.getActivationThreshold();

        MockERC20(address(stakingAsset)).mint(_caller, activationThreshold);
        vm.prank(_caller);
        stakingAsset.approve(address(stakingRegistry), activationThreshold);

        vm.expectEmit(true, true, true, true, address(pullSplitFactory));
        emit SplitFactoryV2.SplitCreated(splitAddress, splitParams, address(0), address(stakingRegistry), uint256(0));
        vm.expectEmit(true, true, true, true, address(stakingRegistry));
        emit IStakingRegistry.StakedWithProvider(providerId, address(rollup), attester, splitAddress, _caller);
        vm.prank(_caller);
        stakingRegistry.stake(
            providerId,
            rollupVersion,
            _withdrawalAddress,
            providerTakeRate,
            _userRewardsRecipient,
            _moveWithLatestRollup
        );

        assertEq(stakingAsset.balanceOf(address(rollup)), activationThreshold);
        assertEq(stakingAsset.balanceOf(address(stakingRegistry)), 0);
        assertEq(stakingAsset.balanceOf(_withdrawalAddress), 0);
    }
}
