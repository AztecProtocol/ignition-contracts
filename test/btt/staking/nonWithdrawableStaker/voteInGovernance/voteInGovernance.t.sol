// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

// Tests
import {StakerTestBase} from "test/btt/staking/StakerTestBase.sol";

// Atp
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {BaseStaker} from "@atp/staker/BaseStaker.sol";

// Mock
import {IPayload} from "test/mocks/staking/MockGovernance.sol";

contract VoteInGovernance is StakerTestBase {
    function setUp() public override {
        super.setUp();

        givenNonWithdrawableStakerIsSet();
    }

    function test_WhenTheCallerNEQOperator(address _caller) external givenATPIsSetUp {
        // it reverts
        vm.assume(_caller != OPERATOR);

        vm.expectRevert(abi.encodeWithSelector(BaseStaker.NotOperator.selector, _caller, OPERATOR));
        vm.prank(_caller);
        IATPNonWithdrawableStaker(address(staker)).voteInGovernance(0, 0, true);
    }

    function test_GivenTheCallerEQOperator(uint256 _amount, bool _support) external givenATPIsSetUp {
        // it votes on a proposal

        uint256 amount = bound(_amount, 1, rollup.getActivationThreshold());

        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).depositIntoGovernance(amount);

        uint256 proposalId = governance.proposeMock(IPayload(address(1)));

        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).voteInGovernance(proposalId, amount, _support);

        (IPayload payload, uint256 yays, uint256 nays) = governance.proposals(proposalId);
        assertEq(address(payload), address(1));
        assertEq(yays, _support ? amount : 0);
        assertEq(nays, _support ? 0 : amount);
    }
}
