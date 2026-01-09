// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Base} from "./Base.sol";
import {IInstance} from "@aztec/core/interfaces/IInstance.sol";
import {Errors} from "@aztec/core/libraries/Errors.sol";

contract SequencerRewardsTest is Base {
    address public ATTESTER = 0xd84E8d45A37626d0ade0d068A485411528cd266F;
    IInstance public INSTANCE;

    function setUp() public override {
        super.setUp();

        INSTANCE = IInstance(tgePayload.ROLLUP());
    }

    function test_claimRewards() public {
        uint256 rewardsOnRollup = INSTANCE.getSequencerRewards(ATTESTER);

        vm.expectRevert(abi.encodeWithSelector(Errors.Rollup__RewardsNotClaimable.selector));
        INSTANCE.claimSequencerRewards(ATTESTER);

        proposeAndExecuteProposal();

        assertEq(AZTEC_TOKEN.balanceOf(ATTESTER), 0);
        INSTANCE.claimSequencerRewards(ATTESTER);
        assertEq(AZTEC_TOKEN.balanceOf(ATTESTER), rewardsOnRollup);
    }
}
