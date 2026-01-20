// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Tests
import {StakerTestBase} from "test/btt/staking/StakerTestBase.sol";

// Atp
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {BaseStaker} from "@atp/staker/BaseStaker.sol";

import {console} from "forge-std/console.sol";

contract DepositIntoGovernanceTest is StakerTestBase {
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

    modifier givenTheCallerIsTheOperator() {
        _;
    }

    function test_WhenAmountIsGTTheBalanceOfTheAtp(uint256 _amount)
        external
        givenTheCallerIsTheOperator
        givenATPIsSetUp
    {
        // it reverts
        uint256 amount = bound(_amount, rollup.getActivationThreshold() + 1, type(uint256).max);

        vm.expectRevert();
        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).depositIntoGovernance(amount);
    }

    function test_GivenTheAmountIsLTETheBalanceOfTheAtp(uint256 _amount)
        external
        givenTheCallerIsTheOperator
        givenATPIsSetUp
    {
        // it deposits into governance
        // it assigns power to the staker contract
        // it has the correct power

        uint256 amount = bound(_amount, 1, rollup.getActivationThreshold());

        uint256 balanceBefore = token.balanceOf(address(userAtp));
        console.log("balanceBefore", balanceBefore);

        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).depositIntoGovernance(amount);

        uint256 balanceAfter = token.balanceOf(address(userAtp));
        assertEq(balanceAfter, balanceBefore - amount);

        assertEq(governance.users(address(staker)), amount);
        assertEq(governance.total(), amount);
    }
}
