// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Tests
import {StakerTestBase} from "test/btt/staking/StakerTestBase.sol";

// Atp
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";

// Mocks
import {MockRegistry} from "test/mocks/staking/MockRegistry.sol";

// Libs
import {Constants} from "src/constants.sol";
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

contract NonWithdrawableStaker is StakerTestBase {
    function setUp() public override {
        super.setUp();

        givenNonWithdrawableStakerIsSet();
    }

    function test_WhenTheVersionOfTheRollupIsNotTheCanonicalOne(uint256 _version) external givenATPIsSetUp {
        // It deposits successfully

        // Canonical rollup version is 0 at this moment
        vm.assume(_version != rollupRegistry.currentVersion());

        assertEq(rollupRegistry.getRollup(rollupRegistry.currentVersion()), rollupRegistry.getCanonicalRollup());

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

    function test_WhenTheVersionOfTheRollupIsTheCanonicalOne(address _attester) external givenATPIsSetUp {
        // It deposits successfully

        uint256 version = rollupRegistry.currentVersion();

        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker))
            .stake(
                version,
                _attester,
                BN254Lib.G1Point({x: 0, y: 0}),
                BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
                BN254Lib.G1Point({x: 0, y: 0}),
                true
            );

        assertEq(rollupRegistry.getRollup(version), rollupRegistry.getCanonicalRollup());

        assertEq(rollup.staked(_attester), rollup.getActivationThreshold());
        assertEq(rollup.isStaked(_attester), true);
        assertEq(rollup.withdrawers(_attester), address(staker));
        assertEq(rollup.isExiting(_attester), false);
    }

    function test_When_moveWithLatestRollupIsTrueButNotSendingToTheCanonicalRollup(address _attester)
        external
        givenATPIsSetUp
    {
        // It reverts
        // It should be able to move the funds back to the ATP
        rollup.setShouldDepositFail(true);

        uint256 version = rollupRegistry.currentVersion();

        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker))
            .stake(
                version,
                _attester,
                BN254Lib.G1Point({x: 0, y: 0}),
                BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
                BN254Lib.G1Point({x: 0, y: 0}),
                true
            );

        // The funds should be in the staker
        assertEq(token.balanceOf(address(staker)), rollup.getActivationThreshold());

        // It should be able to move the funds back to the ATP
        vm.prank(OPERATOR);
        IATPNonWithdrawableStaker(address(staker)).moveFundsBackToATP();

        assertEq(token.balanceOf(address(staker)), 0);
        assertEq(token.balanceOf(address(userAtp)), rollup.getActivationThreshold());
    }
}
