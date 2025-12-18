// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Math} from "@oz/utils/math/Math.sol";
import {LATPTestBase} from "test/token-vaults/latp_base.sol";
import {ILATP, LockParams, RevokableParams} from "test/token-vaults/Importer.sol";

import {Handler} from "test/token-vaults/foundry_invariant/atps/linear/LATPHandler.sol";
import {Math} from "@oz/utils/math/Math.sol";
import {FakeStaker} from "test/token-vaults/mocks/FakeStaker.sol";
import {IERC20Errors} from "@oz/interfaces/draft-IERC6093.sol";

contract Scenario_2 is LATPTestBase {
    Handler internal handler;
    ILATP internal atp;

    uint256 internal allocation = 1001e18 + 1; // +1 to make rounding errors more likely
    address internal operator;

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

        vm.label(address(atp), "atp");

        operator = address(bytes20("operator"));
        help_upgrade(atp, operator);

        assertLt(atp.getGlobalLock().startTime, atp.getAccumulationLock().startTime, "startTime mismatch");

        uint256 upperTime = Math.max(atp.getGlobalLock().endTime, atp.getAccumulationLock().endTime);
        handler.prepare(atp, upperTime);
    }

    function test_scenario_2() public {
        /**
         * This scenario is the same as Lasse pointed out in todo.
         *
         * If the claim does not take into account the allowance given, it is possible to setup an allowance,
         * then claim and then use the allowance, reducing the balance of the LATP down below the revokable amount.
         */
        vm.warp(atp.getAccumulationLock().endTime - 1);

        // Checks

        uint256 accumulated = help_computeAccumulated(atp, block.timestamp);
        assertLe(accumulated, allocation, "accumulated <= allocation");
        uint256 revokable = allocation - accumulated;

        FakeStaker staker = FakeStaker(address(atp.getStaker()));
        vm.label(address(staker), "staker");

        // We approve everyhing that is accumulated
        help_approve(atp, accumulated);

        // We claim the claimable amount
        vm.prank(address(handler));
        atp.claim();

        bool doAction = true;
        if (doAction) {
            // At this point, we still have allowance left, so let us use that to stake
            uint256 stakeAmount = Math.min(accumulated, token.balanceOf(address(atp)));

            // When fixed, this should revert!
            vm.prank(operator);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IERC20Errors.ERC20InsufficientAllowance.selector, address(staker), 0, stakeAmount
                )
            );
            staker.stake(stakeAmount);
        }

        // At this point we should have some "bad" values.
        uint256 balance = token.balanceOf(address(atp));
        uint256 allowance = token.allowance(address(atp), address(staker));

        // Need to ensure that there are enough funds to cover all that can exit.
        assertLe(revokable + allowance, balance, "revokable + allowance <= balance");
    }
}
