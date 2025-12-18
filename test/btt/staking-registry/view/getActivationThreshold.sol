// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {StakingRegistryBase} from "../StakingRegistryBase.sol";

contract GetActivationThreshold is StakingRegistryBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ActivationThreshold_ShouldReturnTheCorrectValue() external {
        // it returns the correct value
        uint256 activationThreshold = stakingRegistry.getActivationThreshold(0);
        assertEq(activationThreshold, gse.ACTIVATION_THRESHOLD());
    }
}
