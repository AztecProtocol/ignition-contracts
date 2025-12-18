// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Tests
import {StakerTestBase} from "test/btt/staking/StakerTestBase.sol";

// Atp
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {IATPWithdrawableStaker} from "src/staking/interfaces/IATPWithdrawableStaker.sol";
import {BaseStaker} from "@atp/staker/BaseStaker.sol";

// Mocks
import {MockRegistry} from "test/mocks/staking/MockRegistry.sol";

// Libs
import {Constants} from "src/constants.sol";
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

contract InitiateWithdraw is StakerTestBase {
    function setUp() public override {
        super.setUp();

        givenNonWithdrawableStakerIsSet();
        givenWithdrawableStakerIsSet();
    }

    function test_WhenTheCallerIsNotTheOperator(address _caller)
        external
        givenATPIsSetUp
        givenATPIsSetUpForWithdrawableStaker
    {
        // it reverts
        vm.assume(_caller != OPERATOR);

        vm.expectRevert(abi.encodeWithSelector(BaseStaker.NotOperator.selector, _caller, OPERATOR));
        vm.prank(_caller);
        IATPWithdrawableStaker(address(staker)).initiateWithdraw(0, address(0));
    }

    modifier givenThatTheCallerIsTheOperator() {
        _;
    }

    function test_WhenTheVersionOfTheRollupDoesNotExist(uint256 _version)
        external
        givenATPIsSetUp
        givenATPIsSetUpForWithdrawableStaker
        givenThatTheCallerIsTheOperator
    {
        // it reverts
        vm.assume(_version != rollupRegistry.currentVersion());

        vm.expectRevert(abi.encodeWithSelector(MockRegistry.InvalidRollupVersion.selector, _version));
        vm.prank(OPERATOR);
        IATPWithdrawableStaker(address(staker)).initiateWithdraw(_version, address(0));
    }

    modifier givenThatTheVersionOfTheRollupExists() {
        _;
    }

    // function test_WhenTheStakerIsNotTheWithdrawer(address _attester)
    //     external
    //     givenATPIsSetUp
    //     givenThatTheCallerIsTheOperator
    //     givenThatTheVersionOfTheRollupExists
    // {
    //     // it reverts

    //     // Perform deposit

    //     upgradeToWithdrawableStaker();

    //     // Perform withdrawal
    // }

    // function test_WhenTheStakerIsTheWithdrawer()
    //     external
    //     givenATPIsSetUp
    //     givenATPIsSetUpForWithdrawableStaker
    //     givenThatTheCallerIsTheOperator
    //     givenThatTheVersionOfTheRollupExists
    // {
    //     // it succeeds
    // }
}
