// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TGEPayload} from "src/tge/TGEPayload.sol";

import {IATPWithdrawableAndClaimableStaker} from "src/staking/interfaces/IATPWithdrawableAndClaimableStaker.sol";
import {ATPWithdrawableAndClaimableStaker} from "src/staking/ATPWithdrawableAndClaimableStaker.sol";
import {Governance} from "@aztec/governance/Governance.sol";
import {Timestamp} from "@aztec/shared/libraries/TimeMath.sol";
import {IATPCore} from "src/token-vaults/atps/linear/ILATP.sol";
import {NCATP} from "src/token-vaults/atps/noclaim/NCATP.sol";
import {StakerVersion} from "@atp/Registry.sol";

import {Base} from "./Base.sol";

contract AuctionBigScenarioTest is Base {
    // Big scenario tests for the holders with more than 200K tokens.
    // The test should show that:
    // 1. A holder that have not staked is unable to withdraw funds (since he has not staked)
    // 2. A holder that have staked is able to withdraw funds after the proposal

    // A holder that have not staked (at least at block 24184039)
    NCATP public BIG_HOLDER_NOT_STAKED = NCATP(0x9c39D1E39582876018Bca56f0F15a26aE1fEfEBF);

    // A holder that have staked
    NCATP public BIG_HOLDER_STAKED = NCATP(0x7FB83F97e29A9af172753aa5428304Dee8073661);

    function test_big_unstaked_holder() public {
        // 1. A holder that have not staked is unable to withdraw funds (since he has not staked)
        // We check this by first upgrading to version 1, then trying to exit, seeing that fail, and then
        // upgrading to the new version (2), seeing that we are past the withdrawal time and then trying
        // again.

        address beneficiary = BIG_HOLDER_NOT_STAKED.getBeneficiary();
        address operator = BIG_HOLDER_NOT_STAKED.getOperator();
        IATPWithdrawableAndClaimableStaker staker =
            IATPWithdrawableAndClaimableStaker(address(BIG_HOLDER_NOT_STAKED.getStaker()));

        // We upgrade the staker to version 1
        vm.prank(beneficiary);
        BIG_HOLDER_NOT_STAKED.upgradeStaker(StakerVersion.wrap(1));
        assertGt(staker.WITHDRAWAL_TIMESTAMP(), block.timestamp);

        vm.expectRevert(abi.encodeWithSelector(ATPWithdrawableAndClaimableStaker.StakingNotOccurred.selector));
        vm.prank(operator);
        staker.withdrawAllTokensToBeneficiary();

        proposeAndExecuteProposal();

        // We upgrade the staker to version 2
        vm.prank(beneficiary);
        BIG_HOLDER_NOT_STAKED.upgradeStaker(STAKER_VERSION);
        assertLt(staker.WITHDRAWAL_TIMESTAMP(), block.timestamp);

        vm.expectRevert(abi.encodeWithSelector(ATPWithdrawableAndClaimableStaker.StakingNotOccurred.selector));
        vm.prank(operator);
        staker.withdrawAllTokensToBeneficiary();
    }

    function test_big_staked_holder() public {
        // We show that it is not possible to withdraw the funds to the beneficiary before proposal
        // After the proposal the staker can be updated to new implementation with earlier withdrawal time.

        address beneficiary = BIG_HOLDER_STAKED.getBeneficiary();
        address operator = BIG_HOLDER_STAKED.getOperator();
        IATPWithdrawableAndClaimableStaker staker =
            IATPWithdrawableAndClaimableStaker(address(BIG_HOLDER_STAKED.getStaker()));

        assertGt(staker.WITHDRAWAL_TIMESTAMP(), EARLIEST_TIME);
        assertGt(staker.WITHDRAWAL_TIMESTAMP(), block.timestamp);

        uint256 atpBalanceBefore = AZTEC_TOKEN.balanceOf(address(BIG_HOLDER_STAKED));
        uint256 userBalanceBefore = AZTEC_TOKEN.balanceOf(beneficiary);
        assertGt(atpBalanceBefore, 0);

        vm.expectRevert(abi.encodeWithSelector(ATPWithdrawableAndClaimableStaker.WithdrawalDelayNotPassed.selector));
        vm.prank(operator);
        staker.withdrawAllTokensToBeneficiary();

        // Execute the proposal
        proposeAndExecuteProposal();

        assertGt(staker.WITHDRAWAL_TIMESTAMP(), EARLIEST_TIME);
        assertGt(staker.WITHDRAWAL_TIMESTAMP(), block.timestamp);

        // The current staker is still the same, no change there.
        vm.expectRevert(abi.encodeWithSelector(ATPWithdrawableAndClaimableStaker.WithdrawalDelayNotPassed.selector));
        vm.prank(operator);
        staker.withdrawAllTokensToBeneficiary();

        // We need to upgrade the staker to version 2
        vm.prank(beneficiary);
        BIG_HOLDER_STAKED.upgradeStaker(STAKER_VERSION);

        assertLe(staker.WITHDRAWAL_TIMESTAMP(), EARLIEST_TIME);
        assertLe(staker.WITHDRAWAL_TIMESTAMP(), block.timestamp);

        vm.prank(beneficiary);
        BIG_HOLDER_STAKED.approveStaker(atpBalanceBefore);

        vm.prank(operator);
        staker.withdrawAllTokensToBeneficiary();

        uint256 atpBalanceAfter = AZTEC_TOKEN.balanceOf(address(BIG_HOLDER_STAKED));
        uint256 userBalanceAfter = AZTEC_TOKEN.balanceOf(beneficiary);
        assertEq(atpBalanceAfter, 0);
        assertEq(userBalanceAfter, userBalanceBefore + atpBalanceBefore);
        assertGt(userBalanceAfter, userBalanceBefore);
    }
}
