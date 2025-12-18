// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {StakingRegistryBase} from "../StakingRegistryBase.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";

contract UpdateProviderAdmin is StakingRegistryBase {
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

    function test_RevertWhen_TheCallerIsNotTheProviderAdmin(address _caller, address _newAdmin) external {
        // It should revert

        vm.assume(_caller != PROVIDER_ADMIN);

        vm.expectRevert(
            abi.encodeWithSelector(IStakingRegistry.StakingRegistry__NotProviderAdmin.selector, PROVIDER_ADMIN)
        );
        vm.prank(_caller);
        stakingRegistry.updateProviderAdmin(1, _newAdmin);

        (address providerAdmin,,) = stakingRegistry.providerConfigurations(providerId);
        assertEq(providerAdmin, PROVIDER_ADMIN);
    }

    function test_WhenTheCallerIsTheProviderAdmin(address _newAdmin) external {
        // It should emit {ProviderAdminUpdated} event
        // It should update the provider admin
        vm.assume(_newAdmin != address(0));
        vm.assume(_newAdmin != PROVIDER_ADMIN);

        vm.prank(PROVIDER_ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IStakingRegistry.ProviderAdminUpdateInitiated(1, _newAdmin);
        stakingRegistry.updateProviderAdmin(1, _newAdmin);

        address pendingProviderAdmin = stakingRegistry.pendingProviderAdmins(1);
        assertEq(pendingProviderAdmin, _newAdmin);
    }

    function test_RevertWhen_TheNewAdminIsTheSameAsTheCurrentProviderAdmin() external {
        // It should revert

        vm.expectRevert(
            abi.encodeWithSelector(IStakingRegistry.StakingRegistry__UpdatedProviderAdminToSameAddress.selector)
        );
        vm.prank(PROVIDER_ADMIN);
        stakingRegistry.updateProviderAdmin(1, PROVIDER_ADMIN);

        (address providerAdmin,,) = stakingRegistry.providerConfigurations(providerId);
        assertEq(providerAdmin, PROVIDER_ADMIN);
    }

    function test_RevertWhen_TheNewAdminIsTheZeroAddress(address _newAdmin) external {
        // It should revert
        vm.assume(_newAdmin != address(0));

        vm.expectRevert(abi.encodeWithSelector(IStakingRegistry.StakingRegistry__ZeroAddress.selector));
        vm.prank(PROVIDER_ADMIN);
        stakingRegistry.updateProviderAdmin(1, address(0));
    }
}
