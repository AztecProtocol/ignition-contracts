// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {StakingRegistryBase} from "../StakingRegistryBase.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";

contract AddKeysToProvider is StakingRegistryBase {
    address public PROVIDER_ADMIN = makeAddr("PROVIDER_ADMIN");
    address public rewardsRecipient = makeAddr("rewardsRecipient");

    function setUp() public override {
        super.setUp();

        stakingRegistry.registerProvider(PROVIDER_ADMIN, 100, rewardsRecipient);
    }

    function test_RevertWhen_TheCallerIsNotTheProviderAdmin(address _caller) external {
        // It should revert

        vm.assume(_caller != PROVIDER_ADMIN);

        IStakingRegistry.KeyStore[] memory keyStores = new IStakingRegistry.KeyStore[](2);
        keyStores[0] = makeKeyStore(address(1));
        keyStores[1] = makeKeyStore(address(2));

        vm.expectRevert(
            abi.encodeWithSelector(IStakingRegistry.StakingRegistry__NotProviderAdmin.selector, PROVIDER_ADMIN)
        );
        vm.prank(_caller);
        stakingRegistry.addKeysToProvider(1, keyStores);
    }

    function test_WhenTheCallerIsTheProviderAdmin(address[] memory _attesters) external {
        // It should be able to add keys to the provider
        // It should emit {AttestersAddedToProvider} event
        vm.assume(_attesters.length > 0);

        IStakingRegistry.KeyStore[] memory keyStores = new IStakingRegistry.KeyStore[](_attesters.length);
        for (uint256 i = 0; i < _attesters.length; i++) {
            keyStores[i] = makeKeyStore(_attesters[i]);
        }

        vm.prank(PROVIDER_ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IStakingRegistry.AttestersAddedToProvider(1, _attesters);
        stakingRegistry.addKeysToProvider(1, keyStores);
    }
}
