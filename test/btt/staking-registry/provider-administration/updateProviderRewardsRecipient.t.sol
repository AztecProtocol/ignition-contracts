// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {StakingRegistryBase} from "../StakingRegistryBase.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {Constants} from "src/constants.sol";

contract UpdateProviderRewardsRecipient is StakingRegistryBase {
    address public PROVIDER_ADMIN = makeAddr("PROVIDER_ADMIN");

    uint256 public providerId;
    address public rewardsRecipient = makeAddr("rewardsRecipient");

    function setUp() public override {
        super.setUp();

        providerId = stakingRegistry.registerProvider(PROVIDER_ADMIN, 100, rewardsRecipient);
    }

    function test_RevertWhen_TheCallerIsNotTheProviderAdmin(address _caller, address _newRewardsRecipient) external {
        // It should revert
        vm.assume(_caller != PROVIDER_ADMIN);

        vm.assume(_newRewardsRecipient != address(0));

        vm.expectRevert(
            abi.encodeWithSelector(IStakingRegistry.StakingRegistry__NotProviderAdmin.selector, PROVIDER_ADMIN)
        );
        vm.prank(_caller);
        stakingRegistry.updateProviderRewardsRecipient(providerId, _newRewardsRecipient);
    }

    modifier givenTheCallerIsTheProviderAdmin() {
        vm.startPrank(PROVIDER_ADMIN);
        _;
    }

    function test_WhenTheRewardsRecipientIsNotZeroAddress(address _newRewardsRecipient)
        external
        givenTheCallerIsTheProviderAdmin
    {
        // It should emit {ProviderRewardsRecipientUpdated} event
        // It should update the provider rewards recipient

        vm.assume(_newRewardsRecipient != address(0));

        vm.expectEmit(true, true, true, true);
        emit IStakingRegistry.ProviderRewardsRecipientUpdated(providerId, _newRewardsRecipient);
        stakingRegistry.updateProviderRewardsRecipient(providerId, _newRewardsRecipient);

        (,, address providerRewardsRecipient) = stakingRegistry.providerConfigurations(providerId);

        assertEq(providerRewardsRecipient, _newRewardsRecipient);
    }

    function test_RevertWhen_TheRewardsRecipientIsZeroAddress() external givenTheCallerIsTheProviderAdmin {
        // It should revert

        vm.expectRevert(abi.encodeWithSelector(IStakingRegistry.StakingRegistry__ZeroAddress.selector));
        stakingRegistry.updateProviderRewardsRecipient(providerId, address(0));
    }
}
