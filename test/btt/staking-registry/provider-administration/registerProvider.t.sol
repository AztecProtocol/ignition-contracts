// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {StakingRegistryBase} from "../StakingRegistryBase.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {Constants} from "src/constants.sol";

contract RegisterProvider is StakingRegistryBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_TheProviderAdminIsTheZeroAddress(uint16 _providerTakeRate, address _rewardsRecipient)
        external
    {
        // It should revert
        _providerTakeRate = uint16(bound(_providerTakeRate, 0, Constants.BIPS));
        vm.assume(_rewardsRecipient != address(0));

        vm.expectRevert(abi.encodeWithSelector(IStakingRegistry.StakingRegistry__ZeroAddress.selector));
        stakingRegistry.registerProvider(address(0), _providerTakeRate, _rewardsRecipient);
    }

    function test_RevertWhen_TheTakeRateIsGreaterThan100(
        address _providerAdmin,
        uint16 _providerTakeRate,
        address _rewardsRecipient
    ) external {
        // It should revert
        vm.assume(_providerAdmin != address(0));
        vm.assume(_rewardsRecipient != address(0));

        _providerTakeRate = uint16(bound(_providerTakeRate, Constants.BIPS + 1, type(uint16).max));

        vm.expectRevert(
            abi.encodeWithSelector(IStakingRegistry.StakingRegistry__InvalidTakeRate.selector, _providerTakeRate)
        );
        stakingRegistry.registerProvider(_providerAdmin, _providerTakeRate, _rewardsRecipient);
    }

    function test_RevertWhen_TheRewardsRecipientIsTheZeroAddress(address _providerAdmin, uint16 _providerTakeRate)
        external
    {
        // It should revert
        vm.assume(_providerAdmin != address(0));
        _providerTakeRate = uint16(bound(_providerTakeRate, 0, Constants.BIPS));

        vm.expectRevert(abi.encodeWithSelector(IStakingRegistry.StakingRegistry__ZeroAddress.selector));
        stakingRegistry.registerProvider(_providerAdmin, _providerTakeRate, address(0));
    }

    function test_WhenTheTakeRateIsLessThanOrEqualTo10000(
        address _providerAdmin,
        uint16 _providerTakeRate,
        address _rewardsRecipient
    ) external {
        // It should register the provider
        _providerTakeRate = uint16(bound(_providerTakeRate, 0, Constants.BIPS));
        vm.assume(_providerAdmin != address(0));
        vm.assume(_rewardsRecipient != address(0));

        uint256 nextProviderId = stakingRegistry.nextProviderIdentifier();

        vm.expectEmit(true, true, true, true);
        emit IStakingRegistry.ProviderRegistered(nextProviderId, _providerAdmin, _providerTakeRate);
        uint256 providerId = stakingRegistry.registerProvider(_providerAdmin, _providerTakeRate, _rewardsRecipient);

        (address providerAdmin, uint16 providerTakeRate, address providerRewardsRecipient) =
            stakingRegistry.providerConfigurations(providerId);
        assertEq(providerAdmin, _providerAdmin);
        assertEq(providerTakeRate, _providerTakeRate);
        assertEq(providerRewardsRecipient, _rewardsRecipient);
    }
}
