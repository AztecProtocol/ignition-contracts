// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Tests
import {StakerTestBase} from "test/btt/staking/StakerTestBase.sol";

// Atp
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {ATPNonWithdrawableStaker} from "src/staking/ATPNonWithdrawableStaker.sol";
import {BaseStaker} from "@atp/staker/BaseStaker.sol";

// Mocks
import {MockRegistry} from "test/mocks/staking/MockRegistry.sol";

// Libs
import {Constants} from "src/constants.sol";
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

contract Stake is StakerTestBase {
    function setUp() public override {
        super.setUp();

        givenNonWithdrawableStakerIsSet();
    }

    modifier givenTheCallerIsTheOperator() {
        _;
    }

    function test_WhenTheCallerIsNotTheOperator(address _caller) external givenATPIsSetUp {
        // it reverts
        vm.assume(_caller != OPERATOR);

        vm.expectRevert(abi.encodeWithSelector(BaseStaker.NotOperator.selector, _caller, OPERATOR));
        vm.prank(_caller);
        IATPNonWithdrawableStaker(address(staker))
            .stake(
                0,
                address(0),
                BN254Lib.G1Point({x: 0, y: 0}),
                BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
                BN254Lib.G1Point({x: 0, y: 0}),
                true
            );
    }

    function test_WhenTheRollupVersionDoesNotExist(uint256 _version)
        external
        givenATPIsSetUp
        givenTheCallerIsTheOperator
    {
        vm.assume(_version != rollupRegistry.currentVersion());

        // it reverts
        vm.expectRevert(abi.encodeWithSelector(MockRegistry.InvalidRollupVersion.selector, _version));
        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker))
            .stake(
                _version,
                address(0),
                BN254Lib.G1Point({x: 0, y: 0}),
                BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
                BN254Lib.G1Point({x: 0, y: 0}),
                true
            );
    }

    function test_GivenThatTheCallerIsTheOperator(address _attester)
        external
        givenATPIsSetUp
        givenTheCallerIsTheOperator
    {
        // it deposits into the rollup with the attester
        // it deploys a splits contract with the expected stake rate
        // it sets the staker as the withdrawer

        vm.expectEmit(true, true, true, true, address(staker));
        emit ATPNonWithdrawableStaker.Staked(address(staker), _attester, address(rollup));
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

        // Note: testing the mock rollup here - not the real one - but it functions the same way
        assertEq(rollup.withdrawers(_attester), address(staker));
        assertEq(rollup.staked(_attester), rollup.getActivationThreshold());
        assertEq(rollup.isStaked(_attester), true);
        assertEq(rollup.isExiting(_attester), false);
    }
}
