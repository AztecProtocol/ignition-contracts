// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Tests
import {StakerTestBase} from "test/btt/staking/StakerTestBase.sol";

// Atp
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {BaseStaker} from "@atp/staker/BaseStaker.sol";

// Mocks
import {MockRegistry} from "test/mocks/staking/MockRegistry.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

// Libs
import {Constants} from "src/constants.sol";

contract ClaimRewards is StakerTestBase {
    function setUp() public override {
        super.setUp();

        givenNonWithdrawableStakerIsSet();
    }

    function test_WhenTheCallerIsNotTheOperator(address _caller) external givenATPIsSetUp {
        // It reverts
        vm.assume(_caller != BENEFICIARY);
        vm.assume(_caller != OPERATOR);
        rollup.setAreRewardsClaimable(true);

        vm.expectRevert(abi.encodeWithSelector(BaseStaker.NotOperator.selector, _caller, OPERATOR));
        vm.prank(_caller);
        IATPNonWithdrawableStaker(address(staker)).claimRewards(0);
    }

    modifier givenTheCallerIsTheOperator() {
        _;
    }

    function test_WhenTheRollupVersionDoesNotExist(uint256 _version)
        external
        givenATPIsSetUp
        givenTheCallerIsTheOperator
    {
        // It reverts
        vm.assume(_version != rollupRegistry.currentVersion());

        vm.expectRevert(abi.encodeWithSelector(MockRegistry.InvalidRollupVersion.selector, _version));
        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).delegate(_version, address(0), address(0));
    }

    function test_claimingRewards(uint128 _rewardAmount) external givenATPIsSetUp givenTheCallerIsTheOperator {
        vm.assume(_rewardAmount > 0);

        MockERC20(address(token)).mint(address(rollup), _rewardAmount);
        rollup.reward(address(userAtp), _rewardAmount);
        rollup.setAreRewardsClaimable(true);

        // It succeeds
        uint256 version = rollupRegistry.currentVersion();
        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).claimRewards(version);

        assertEq(token.balanceOf(address(userAtp)), rollup.getActivationThreshold() + _rewardAmount);
    }
}
