// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {StakingRegistryBase} from "../StakingRegistryBase.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {Constants} from "src/constants.sol";

contract UpdateProviderTakeRate is StakingRegistryBase {
    address public PROVIDER_ADMIN = makeAddr("PROVIDER_ADMIN");

    uint256 public providerId;
    address public rewardsRecipient = makeAddr("rewardsRecipient");

    function setUp() public override {
        super.setUp();

        providerId = stakingRegistry.registerProvider(PROVIDER_ADMIN, 100, rewardsRecipient);
    }

    function test_RevertWhen_TheCallerIsNotTheProviderAdmin(address _caller, uint16 _newTakeRate) external {
        // It should revert
        vm.assume(_caller != PROVIDER_ADMIN);

        _newTakeRate = uint16(bound(_newTakeRate, 0, Constants.BIPS));

        vm.expectRevert(
            abi.encodeWithSelector(IStakingRegistry.StakingRegistry__NotProviderAdmin.selector, PROVIDER_ADMIN)
        );
        vm.prank(_caller);
        stakingRegistry.updateProviderTakeRate(providerId, _newTakeRate);
    }

    modifier givenTheCallerIsTheProviderAdmin() {
        vm.startPrank(PROVIDER_ADMIN);
        _;
    }

    function test_WhenTheTakeRateIsLessThanConstantsBIPS(uint16 _newTakeRate)
        external
        givenTheCallerIsTheProviderAdmin
    {
        // It should emit {ProviderTakeRateUpdated} event
        // It should update the provider take rate
        (, uint16 currentTakeRate,) = stakingRegistry.providerConfigurations(providerId);

        _newTakeRate = uint16(bound(_newTakeRate, 0, Constants.BIPS));
        vm.assume(_newTakeRate != currentTakeRate);

        vm.expectEmit(true, true, true, true);
        emit IStakingRegistry.ProviderTakeRateUpdated(providerId, _newTakeRate);
        stakingRegistry.updateProviderTakeRate(providerId, _newTakeRate);

        (, uint16 providerTakeRate,) = stakingRegistry.providerConfigurations(providerId);

        assertEq(providerTakeRate, _newTakeRate);
    }

    function test_RevertWhen_TheTakeRateIsTheSameAsTheCurrentTakeRate() external givenTheCallerIsTheProviderAdmin {
        // It should revert

        (, uint16 currentTakeRate,) = stakingRegistry.providerConfigurations(providerId);

        vm.expectRevert(
            abi.encodeWithSelector(IStakingRegistry.StakingRegistry__UpdatedProviderTakeRateToSameValue.selector)
        );
        stakingRegistry.updateProviderTakeRate(providerId, currentTakeRate);
    }

    function test_RevertWhen_TheTakeRateIsGreaterThanConstantsBIPS(uint16 _newTakeRate)
        external
        givenTheCallerIsTheProviderAdmin
    {
        // It should revert
        (, uint16 currentTakeRate,) = stakingRegistry.providerConfigurations(providerId);
        vm.assume(_newTakeRate != currentTakeRate);

        _newTakeRate = uint16(bound(_newTakeRate, Constants.BIPS + 1, type(uint16).max));

        vm.expectRevert(
            abi.encodeWithSelector(IStakingRegistry.StakingRegistry__InvalidTakeRate.selector, _newTakeRate)
        );
        stakingRegistry.updateProviderTakeRate(providerId, _newTakeRate);
    }
}
