// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IATPWithdrawableAndClaimableStaker} from "src/staking/interfaces/IATPWithdrawableAndClaimableStaker.sol";
import {IATPWithdrawableStaker} from "src/staking/interfaces/IATPWithdrawableStaker.sol";
import {NCATP} from "src/token-vaults/atps/noclaim/NCATP.sol";
import {IStaking} from "@aztec/core/interfaces/IStaking.sol";
import {Timestamp} from "@aztec/shared/libraries/TimeMath.sol";

import {Base} from "./Base.sol";

contract FinalizeWithdrawTest is Base {
    NCATP public ATP = NCATP(0xE1ea32a54F4FB323dBbE760384617CAa7aa0f331);
    address public ATTESTER = 0x0Ce7B6316E7dA7d02f6f98001296bb7E77aaDAE1;

    function test_finalizeWithdraw() public {
        IATPWithdrawableAndClaimableStaker staker = IATPWithdrawableAndClaimableStaker(address(ATP.getStaker()));

        address operator = ATP.getOperator();
        address beneficiary = ATP.getBeneficiary();

        IStaking rollup = IStaking(tgePayload.ROLLUP());

        // 1. Initiate a withdrawal
        vm.prank(operator);
        IATPWithdrawableStaker(address(staker)).initiateWithdraw(0, ATTESTER);

        // 2. Time jump past the exit delay
        Timestamp exitDelay = rollup.getExitDelay();
        vm.warp(block.timestamp + Timestamp.unwrap(exitDelay) + 1);

        // 3. Show that calling finalizeWithdraw on the V1 staker does NOT work
        // The V1 staker calls IStaking(rollup).finaliseWithdraw (British spelling)
        // but the actual rollup has finalizeWithdraw (American spelling)
        vm.expectRevert();
        IATPWithdrawableStaker(address(staker)).finalizeWithdraw(0, ATTESTER);

        // 4. List the new implementation using proposeAndExecuteProposal
        proposeAndExecuteProposal();

        // 5. Upgrade into the new implementation (V2)
        vm.prank(beneficiary);
        ATP.upgradeStaker(STAKER_VERSION);

        // 6. Call finalizeWithdraw and see that it works
        uint256 atpBalanceBefore = AZTEC_TOKEN.balanceOf(address(ATP));

        IATPWithdrawableStaker(address(staker)).finalizeWithdraw(0, ATTESTER);

        // The funds should have been returned to the ATP
        assertGt(AZTEC_TOKEN.balanceOf(address(ATP)), atpBalanceBefore, "Funds should have been returned to ATP");
    }
}
