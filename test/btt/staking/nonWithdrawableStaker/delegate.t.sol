// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Tests
import {StakerTestBase} from "test/btt/staking/StakerTestBase.sol";

// Atp
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {BaseStaker} from "@atp/staker/BaseStaker.sol";

// Mocks
import {MockGSE} from "test/mocks/staking/MockGSE.sol";
import {MockRegistry} from "test/mocks/staking/MockRegistry.sol";

// Libs
import {Constants} from "src/constants.sol";
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

contract Delegate is StakerTestBase {
    function setUp() public override {
        super.setUp();

        givenNonWithdrawableStakerIsSet();
    }

    function test_WhenTheCallerIsNotTheOperator(address _caller) external givenATPIsSetUp {
        // It reverts
        vm.assume(_caller != BENEFICIARY);

        vm.expectRevert(abi.encodeWithSelector(BaseStaker.NotOperator.selector, _caller, OPERATOR));
        vm.prank(_caller);
        IATPNonWithdrawableStaker(address(staker)).delegate(0, address(0), address(0));
    }

    modifier givenTheCallerIsTheOperator() {
        _;
    }

    function test_WhenTheUserHasNotDeposited(address _attester, address _delegatee)
        external
        givenATPIsSetUp
        givenTheCallerIsTheOperator
    {
        // It reverts
        vm.prank(OPERATOR);
        vm.expectRevert(abi.encodeWithSelector(MockGSE.NotTheWithdrawer.selector));
        IATPNonWithdrawableStaker(address(staker)).delegate(0, _attester, _delegatee);
    }

    function test_WhenTheyDelegateToTheAtp(address _attester, address _delegatee, address _secondDelegatee)
        external
        givenATPIsSetUp
        givenTheCallerIsTheOperator
    {
        // It succeeds
        // It allows the user to delegate again

        vm.assume(_attester != address(0));
        vm.assume(_delegatee != address(0));
        vm.assume(_secondDelegatee != address(0));

        vm.assume(_attester != _delegatee);
        vm.assume(_attester != _secondDelegatee);
        vm.assume(_delegatee != _secondDelegatee);

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

        uint256 delegateePowerBefore = gse.powers(_delegatee);

        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).delegate(0, _attester, _delegatee);

        uint256 delegateePowerAfter = gse.powers(_delegatee);

        assertEq(delegateePowerAfter, delegateePowerBefore + rollup.getActivationThreshold());

        // Reading delegation on a mock rollup right now

        // It allows the user to delegate again
        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).delegate(0, _attester, _secondDelegatee);

        delegateePowerAfter = gse.powers(_delegatee);
        uint256 secondDelegateePowerAfter = gse.powers(_secondDelegatee);

        assertEq(delegateePowerAfter, 0);
        assertEq(secondDelegateePowerAfter, rollup.getActivationThreshold() + delegateePowerBefore);
    }

    function test_WhenTheRollupVersionDoesNotExist(uint256 _version)
        external
        givenATPIsSetUp
        givenTheCallerIsTheOperator
    {
        // It reverts
        vm.assume(_version != rollupRegistry.currentVersion());

        vm.prank(OPERATOR);
        vm.expectRevert(abi.encodeWithSelector(MockRegistry.InvalidRollupVersion.selector, _version));
        IATPNonWithdrawableStaker(address(staker)).delegate(_version, address(0), address(0));
    }
}
