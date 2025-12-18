// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

// Tests
import {StakerTestBase} from "test/btt/staking/StakerTestBase.sol";

// Atp
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {BaseStaker} from "@atp/staker/BaseStaker.sol";

contract InitiateWithdrawFromGoverance is StakerTestBase {
    function setUp() public override {
        super.setUp();

        givenNonWithdrawableStakerIsSet();
    }

    function test_WhenTheCallerNEQOperator(address _caller, uint256 _amount) external givenATPIsSetUp {
        // it reverts
        vm.assume(_caller != OPERATOR);

        vm.expectRevert(abi.encodeWithSelector(BaseStaker.NotOperator.selector, _caller, OPERATOR));
        vm.prank(_caller);
        IATPNonWithdrawableStaker(address(staker)).depositIntoGovernance(_amount);
    }

    modifier givenThatSenderIsEQOperator() {
        _;
    }

    function test_WhenWithdrawingMoreAmountThanBalance(uint256 _amount)
        external
        givenThatSenderIsEQOperator
        givenATPIsSetUp
    {
        // it reverts
        uint256 amount = bound(_amount, 1, rollup.getActivationThreshold());

        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).depositIntoGovernance(amount);

        vm.expectRevert();
        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).initiateWithdrawFromGovernance(amount + 1);
    }

    function test_GivenWithdrawingLessThanTheAmountInGovernance(uint256 _amount)
        external
        givenThatSenderIsEQOperator
        givenATPIsSetUp
    {
        // it initiates a withdrawal to the ATP
        uint256 amount = bound(_amount, 1, rollup.getActivationThreshold());

        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).depositIntoGovernance(amount);

        vm.prank(OPERATOR);
        uint256 withdrawalId = IATPNonWithdrawableStaker(address(staker)).initiateWithdrawFromGovernance(amount);

        (uint256 withdrawalAmount,, address recipient, bool claimed) = governance.withdrawals(withdrawalId);

        assertEq(withdrawalAmount, amount);
        assertEq(recipient, address(userAtp));
        assertEq(claimed, false);
    }
}
