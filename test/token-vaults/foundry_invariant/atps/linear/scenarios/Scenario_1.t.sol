// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Math} from "@oz/utils/math/Math.sol";
import {LATPTestBase} from "test/token-vaults/latp_base.sol";
import {ILATP, LockParams, RevokableParams} from "test/token-vaults/Importer.sol";

import {Handler} from "test/token-vaults/foundry_invariant/atps/linear/LATPHandler.sol";

contract Scenario_1 is LATPTestBase {
    Handler internal handler;
    ILATP internal atp;

    uint256 internal allocation = 1001e18 + 1; // +1 to make rounding errors more likely

    function setUp() public virtual override {
        super.setUp();

        registry.setExecuteAllowedAt(0);

        handler = new Handler();

        atp = atpFactory.createLATP(
            address(handler),
            allocation,
            RevokableParams({
                revokeBeneficiary: revokeBeneficiary,
                lockParams: LockParams({
                    startTime: unlockStartTime + 125, cliffDuration: 250 * 3 / 2, lockDuration: 1000 * 3 / 2
                })
            })
        );

        help_upgrade(atp, address(handler));

        assertLt(atp.getGlobalLock().startTime, atp.getAccumulationLock().startTime, "startTime mismatch");

        uint256 upperTime = Math.max(atp.getGlobalLock().endTime, atp.getAccumulationLock().endTime);
        handler.prepare(atp, upperTime);
    }

    function test_scenario_1() public {
        /**
         * This scenario is the same as Palla pointed out.
         * If the global lock ends before the accumulation, the claimable would be bounded by the unlocked amount, (it should not).
         * This is usually not an issue because the unlocked amount would be the full allocation, but in the case of
         * a surplus, say from rewards or something that have entered by mistake, it would mean that the these
         * would not be claimable before both locks have ended.
         *
         * Showcasing the issue is fairly simple, give a reward and advance to after global lock have ended and for
         * the balance - revokable amount to be greater than the unlock.
         */
        handler.giveReward(10e18);
        vm.warp(atp.getAccumulationLock().endTime - 1);

        // Checks

        uint256 accumulated = help_computeAccumulated(atp, block.timestamp);
        assertLe(accumulated, allocation, "accumulated <= allocation");
        uint256 revokable = allocation - accumulated;

        uint256 claimable = atp.getClaimable();
        uint256 balance = token.balanceOf(address(atp));

        assertLe(claimable + revokable, balance, "claimable + revokable <= balance");
        assertEq(claimable, balance - revokable, "exitable");

        assertEq(allocation + handler.reward(), balance, "allocation == atp balance + rewards");
    }
}
