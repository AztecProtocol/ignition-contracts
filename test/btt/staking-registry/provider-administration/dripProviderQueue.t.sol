// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {StakingRegistryBase} from "test/btt/staking-registry/StakingRegistryBase.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {QueueLib} from "src/staking-registry/libs/QueueLib.sol";

contract DripProviderQueue is StakingRegistryBase {
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

    function test_RevertWhen_TheCallerIsNotTheProviderAdmin(address _caller, uint256 _providerIdentifier) external {
        // it should revert

        vm.assume(_caller != PROVIDER_ADMIN);
        vm.assume(_caller != address(0));

        vm.expectRevert(
            abi.encodeWithSelector(IStakingRegistry.StakingRegistry__NotProviderAdmin.selector, _providerIdentifier)
        );
        vm.prank(_caller);
        stakingRegistry.dripProviderQueue(_providerIdentifier, 1);
    }

    modifier givenTheCallerIsTheProviderAdmin() {
        _;
    }

    function test_RevertWhen_TheProviderQueueIsEmpty() external givenTheCallerIsTheProviderAdmin {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(QueueLib.QueueIsEmpty.selector));
        vm.prank(PROVIDER_ADMIN);
        stakingRegistry.dripProviderQueue(providerId, 1);
    }

    function test_WhenTheProviderQueueIsNotEmpty() external givenTheCallerIsTheProviderAdmin {
        // it should emit {ProviderQueueDripped} event
        // it should drip the provider queue
        address attester = makeAddr("attester");

        IStakingRegistry.KeyStore[] memory providerKeys = new IStakingRegistry.KeyStore[](1);
        providerKeys[0] = makeKeyStore(attester);

        vm.prank(PROVIDER_ADMIN);
        stakingRegistry.addKeysToProvider(providerId, providerKeys);

        vm.prank(PROVIDER_ADMIN);
        vm.expectEmit(true, true, true, true, address(stakingRegistry));
        emit IStakingRegistry.ProviderQueueDripped(providerId, attester);
        stakingRegistry.dripProviderQueue(providerId, 1);
    }

    function test_CanDripMultipleKeys(uint8 _numberOfKeysToDrip) external givenTheCallerIsTheProviderAdmin {
        // it should emit {ProviderQueueDripped} event
        // it should drip the provider queue
        IStakingRegistry.KeyStore[] memory providerKeys = new IStakingRegistry.KeyStore[](_numberOfKeysToDrip);
        for (uint8 i; i < _numberOfKeysToDrip; ++i) {
            string memory attesterName = string(abi.encodePacked("attester", vm.toString(i)));
            providerKeys[i] = makeKeyStore(makeAddr(attesterName));
        }

        vm.prank(PROVIDER_ADMIN);
        stakingRegistry.addKeysToProvider(providerId, providerKeys);

        vm.prank(PROVIDER_ADMIN);
        for (uint8 i; i < _numberOfKeysToDrip; ++i) {
            string memory attesterName = string(abi.encodePacked("attester", vm.toString(i)));
            vm.expectEmit(true, true, true, true, address(stakingRegistry));
            emit IStakingRegistry.ProviderQueueDripped(providerId, makeAddr(attesterName));
        }
        stakingRegistry.dripProviderQueue(providerId, _numberOfKeysToDrip);
    }
}
