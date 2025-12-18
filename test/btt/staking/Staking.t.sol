// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {ILATP} from "@atp/atps/linear/ILATP.sol";
import {IATPCore} from "@atp/atps/base/IATP.sol";
import {ATPFactory, RevokableParams} from "@atp/ATPFactory.sol";
import {StakerVersion} from "@atp/Registry.sol";
import {LockLib} from "@atp/libraries/LockLib.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {StakerTestBase} from "./StakerTestBase.sol";

// Contracts - Staking
import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
import {IATPWithdrawableStaker} from "src/staking/interfaces/IATPWithdrawableStaker.sol";

// Libraries
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";
import {Constants} from "src/constants.sol";

contract StakingTest is StakerTestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_deposit_non_withdrawable_upgrade_staker_to_withdrawable(
        address _beneficiary,
        address _operator,
        address _attester
    ) public {
        vm.assume(_beneficiary != address(0));
        vm.assume(_operator != address(0));
        vm.assume(_attester != address(0));

        uint256 rollupVersion = 0;
        uint256 stakeAmount = rollup.getActivationThreshold();

        BN254Lib.G1Point memory publicKeyG1 = BN254Lib.G1Point({x: 0, y: 0});
        BN254Lib.G2Point memory publicKeyG2 = BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0});
        BN254Lib.G1Point memory signature = BN254Lib.G1Point({x: 0, y: 0});

        // When execute is allowed + 1
        // TODO: update - 1st of January 2027
        vm.warp(1798761600 + 1);

        // Give the atp factory tokens to create the ATP
        MockERC20(address(token)).mint(address(factory), stakeAmount);

        atpRegistry.registerStakerImplementation(address(nonWithdrawableStaker));

        // Create a new ATP
        ILATP atp = factory.createLATP(
            _beneficiary, stakeAmount, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
        );

        ///////////////////////////////////////////////////////
        // Set up ATP operator
        ///////////////////////////////////////////////////////

        // Staker
        address staker = address(atp.getStaker());

        // Set the operator of the ATP to the operator
        vm.prank(_beneficiary);
        vm.expectEmit(true, true, true, true, address(atp));
        emit IATPCore.StakerOperatorUpdated(_operator);
        atp.updateStakerOperator(_operator);

        assertEq(atp.getOperator(), _operator);

        ///////////////////////////////////////////////////////
        // Beneficiary updates staker implementation
        ///////////////////////////////////////////////////////

        // Upgrade to the staker implementation
        vm.prank(_beneficiary);
        vm.expectEmit(true, true, true, true, address(atp));
        emit IATPCore.StakerUpgraded(StakerVersion.wrap(1));
        atp.upgradeStaker(StakerVersion.wrap(1));

        ///////////////////////////////////////////////////////
        // Beneficiary approves the staker
        ///////////////////////////////////////////////////////

        // Approve the staker
        vm.prank(_beneficiary);
        atp.approveStaker(stakeAmount);

        ///////////////////////////////////////////////////////
        // Operator stakes the ATP
        ///////////////////////////////////////////////////////

        // Stake the ATP
        vm.prank(_operator);
        IATPNonWithdrawableStaker(staker).stake(rollupVersion, _attester, publicKeyG1, publicKeyG2, signature, true);

        // We expect a withdraw call to revert as it is not implemented on the current staker
        vm.expectRevert();
        IATPWithdrawableStaker(staker).initiateWithdraw(rollupVersion, _attester);

        ///////////////////////////////////////////////////////
        // Registry registers a new staker implementation
        ///////////////////////////////////////////////////////

        // Upgrade to the new staker implementation
        atpRegistry.registerStakerImplementation(address(withdrawableStaker));

        ///////////////////////////////////////////////////////
        // Beneficiary upgrades the staker
        ///////////////////////////////////////////////////////

        vm.prank(_beneficiary);
        atp.upgradeStaker(StakerVersion.wrap(2));

        ///////////////////////////////////////////////////////
        // Operator initiates the withdrawal
        ///////////////////////////////////////////////////////

        // Initiate the withdrawal
        vm.prank(_operator);
        IATPWithdrawableStaker(staker).initiateWithdraw(rollupVersion, _attester);

        // Finalize withdrawl
        vm.prank(_operator);
        IATPWithdrawableStaker(staker).finalizeWithdraw(rollupVersion, _attester);

        ///////////////////////////////////////////////////////
        // Assert that the ATP gets the funds
        ///////////////////////////////////////////////////////

        // Assert that the ATP gets the funds
        assertEq(token.balanceOf(address(atp)), stakeAmount);
    }
}
