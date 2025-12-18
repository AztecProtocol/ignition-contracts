// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {StakingRegistryBase} from "../StakingRegistryBase.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";

contract AcceptProviderAdmin is StakingRegistryBase {
    address public PROVIDER_ADMIN = makeAddr("PROVIDER_ADMIN");

    uint256 public providerId;
    address public rewardsRecipient = makeAddr("rewardsRecipient");

    function setUp() public override {
        super.setUp();

        providerId = stakingRegistry.registerProvider(
            PROVIDER_ADMIN,
            /*take rate*/
            10,
            rewardsRecipient
        );
    }

    function test_RevertWhen_TheCallerIsNotThePendingProviderAdmin(address _caller, address _newAdmin) external {
        // It should revert
        vm.assume(_newAdmin != address(0));
        vm.assume(_caller != _newAdmin);
        vm.assume(_newAdmin != PROVIDER_ADMIN);

        vm.expectEmit(true, true, true, true);
        emit IStakingRegistry.ProviderAdminUpdateInitiated(1, _newAdmin);
        vm.prank(PROVIDER_ADMIN);
        stakingRegistry.updateProviderAdmin(1, _newAdmin);

        vm.expectRevert(abi.encodeWithSelector(IStakingRegistry.StakingRegistry__NotPendingProviderAdmin.selector));
        vm.prank(_caller);
        stakingRegistry.acceptProviderAdmin(1);

        (address providerAdmin,,) = stakingRegistry.providerConfigurations(providerId);
        assertEq(providerAdmin, PROVIDER_ADMIN);
    }

    function test_WhenTheCallerIsThePendingProviderAdmin(address _newAdmin) external {
        // It should emit {ProviderAdminUpdated} event
        // It should update the provider admin
        // It should delete the pending provider admin
        vm.assume(_newAdmin != address(0));
        vm.assume(_newAdmin != PROVIDER_ADMIN);

        vm.prank(PROVIDER_ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IStakingRegistry.ProviderAdminUpdateInitiated(1, _newAdmin);
        stakingRegistry.updateProviderAdmin(1, _newAdmin);

        address pendingProviderAdmin = stakingRegistry.pendingProviderAdmins(1);
        assertEq(pendingProviderAdmin, _newAdmin);

        vm.prank(_newAdmin);
        vm.expectEmit(true, true, true, true);
        emit IStakingRegistry.ProviderAdminUpdated(1, _newAdmin);
        stakingRegistry.acceptProviderAdmin(1);

        (address providerAdmin,,) = stakingRegistry.providerConfigurations(providerId);
        assertEq(providerAdmin, _newAdmin);
    }
}
