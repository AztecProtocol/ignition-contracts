// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Tests
import {StakerTestBase} from "test/btt/staking/StakerTestBase.sol";

// Atp
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {BaseStaker} from "@atp/staker/BaseStaker.sol";

// Mocks
import {MockERC20} from "test/mocks/MockERC20.sol";

// Libs
import {Constants} from "src/constants.sol";
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

contract MoveFundsBackToATP is StakerTestBase {
    function setUp() public override {
        super.setUp();

        givenNonWithdrawableStakerIsSet();
    }

    function test_WhenTheCallerIsNotTheOperator(address _caller) external givenATPIsSetUp {
        // It reverts
        vm.assume(_caller != OPERATOR);

        vm.expectRevert(abi.encodeWithSelector(BaseStaker.NotOperator.selector, _caller, OPERATOR));
        vm.prank(_caller);
        IATPNonWithdrawableStaker(address(staker)).moveFundsBackToATP();
    }

    modifier givenTheCallerIsTheOperator() {
        _;
    }

    function test_WhenThereAreFundsInTheStaker() external givenATPIsSetUp givenTheCallerIsTheOperator {
        // It succeeds
        MockERC20(address(token)).mint(address(staker), rollup.getActivationThreshold());

        uint256 stakerBalanceBefore = token.balanceOf(address(staker));
        uint256 atpBalanceBefore = token.balanceOf(address(userAtp));

        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).moveFundsBackToATP();

        uint256 stakerBalanceAfter = token.balanceOf(address(staker));
        uint256 atpBalanceAfter = token.balanceOf(address(userAtp));

        assertEq(stakerBalanceAfter, 0);
        assertEq(atpBalanceAfter, atpBalanceBefore + stakerBalanceBefore);
    }

    function test_WhenTheDepositFailsAndReturnsFundsToTheWithdrawer(address _attester)
        external
        givenATPIsSetUp
        givenTheCallerIsTheOperator
    {
        // It succeeds
        rollup.setShouldDepositFail(true);

        // Perform a deposit that will fail and return funds to the withdrawer
        // This happens when the deposit after going through the queue fails
        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker))
            .stake(
                0,
                _attester,
                BN254Lib.G1Point({x: 0, y: 0}),
                BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
                BN254Lib.G1Point({x: 0, y: 0}),
                true
            );

        uint256 stakerBalanceBefore = token.balanceOf(address(staker));
        uint256 atpBalanceBefore = token.balanceOf(address(userAtp));

        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).moveFundsBackToATP();

        uint256 stakerBalanceAfter = token.balanceOf(address(staker));
        uint256 atpBalanceAfter = token.balanceOf(address(userAtp));

        assertEq(stakerBalanceAfter, 0);
        assertEq(atpBalanceAfter, atpBalanceBefore + stakerBalanceBefore);
    }
}
