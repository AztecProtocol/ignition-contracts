// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IATPWithdrawableAndClaimableStaker} from "src/staking/interfaces/IATPWithdrawableAndClaimableStaker.sol";
import {Governance} from "@aztec/governance/Governance.sol";
import {NCATP} from "src/token-vaults/atps/noclaim/NCATP.sol";

import {Base} from "./Base.sol";

contract DelegationTest is Base {
    NCATP public ATP = NCATP(0xE1ea32a54F4FB323dBbE760384617CAa7aa0f331);
    address public ATTESTER = 0x0Ce7B6316E7dA7d02f6f98001296bb7E77aaDAE1;

    function test_delegateFollowingToSelf() public {
        IATPWithdrawableAndClaimableStaker staker = IATPWithdrawableAndClaimableStaker(address(ATP.getStaker()));

        address operator = ATP.getOperator();
        address beneficiary = ATP.getBeneficiary();
        uint256 beneficiaryPowerBefore = GSE.getVotingPower(beneficiary);

        vm.prank(operator);
        staker.delegate(0, ATTESTER, beneficiary);

        // Unchanged since it only delegates what was directly for the instance
        assertEq(GSE.getVotingPower(beneficiary), beneficiaryPowerBefore);

        // Execute the proposal
        proposeAndExecuteProposal();

        // We need to upgrade the staker. This way we get the updated delegate function.
        vm.prank(beneficiary);
        ATP.upgradeStaker(STAKER_VERSION);

        beneficiaryPowerBefore = GSE.getVotingPower(beneficiary);

        vm.prank(operator);
        staker.delegate(0, ATTESTER, beneficiary);

        // Ensure that it increased! It is now working, wuhu
        assertGt(GSE.getVotingPower(beneficiary), beneficiaryPowerBefore);
    }

    function test_delegateExitNoOp() public {
        // Test that will upgrade and delegate to self, then exit and do another delegation (effective no-op).
        test_delegateFollowingToSelf();

        IATPWithdrawableAndClaimableStaker staker = IATPWithdrawableAndClaimableStaker(address(ATP.getStaker()));

        address operator = ATP.getOperator();
        address beneficiary = ATP.getBeneficiary();

        assertGt(GSE.getVotingPower(beneficiary), 0);

        vm.prank(operator);
        staker.initiateWithdraw(0, ATTESTER);

        assertEq(GSE.getVotingPower(beneficiary), 0);

        // Delegating
        vm.prank(operator);
        staker.delegate(0, ATTESTER, beneficiary);

        // Ensure that no power was delegated since no balance after withdrawal initiated
        assertEq(GSE.getVotingPower(beneficiary), 0);
    }
}
