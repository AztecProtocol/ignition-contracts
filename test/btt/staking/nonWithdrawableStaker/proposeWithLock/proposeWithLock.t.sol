// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Tests
import {StakerTestBase} from "test/btt/staking/StakerTestBase.sol";

// Atp
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {BaseStaker} from "@atp/staker/BaseStaker.sol";

// Mock
import {IPayload} from "test/mocks/staking/MockGovernance.sol";

contract ProposeWithLock is StakerTestBase {
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

    function test_GivenTheCallerEQOperator(uint256 _amountDeposited) external givenATPIsSetUp {
        // it sets the withdrawer to be the ATP
        // it passes the proposal along
        uint256 amount = bound(_amountDeposited, 100, rollup.getActivationThreshold());

        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).depositIntoGovernance(amount);

        vm.prank(OPERATOR);
        uint256 proposalId = IATPNonWithdrawableStaker(address(staker)).proposeWithLock(IPayload(address(1)));

        (uint256 withdrawalAmount,, address recipient, bool claimed) = governance.withdrawals(0);

        assertEq(withdrawalAmount, 100); // arbitrary for testing
        assertEq(recipient, address(userAtp)); // important
        assertEq(claimed, false);
    }
}
