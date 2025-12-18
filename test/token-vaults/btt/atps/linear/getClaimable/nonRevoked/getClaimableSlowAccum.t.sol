// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {LockParams, RevokableParams} from "test/token-vaults/Importer.sol";
import {GetClaimableNonRevokedTest} from "./getClaimableNonRevoked.sol";

/**
 * @notice  Test where there are 2 curves, the global lock and the accumulation
 *          The curves are here defined such that the accumulation is slower than the unlock here.
 */
contract GetClaimableSlowAccumTest is GetClaimableNonRevokedTest {
    function deploy() internal virtual override {
        uint256 allocation = 100e18;

        atp = atpFactory.createLATP(
            address(this),
            allocation,
            RevokableParams({
                revokeBeneficiary: revokeBeneficiary,
                lockParams: LockParams({
                    startTime: unlockStartTime, cliffDuration: 250 * 3 / 2, lockDuration: 1000 * 3 / 2
                })
            })
        );

        assertEq(atp.getGlobalLock().startTime, atp.getAccumulationLock().startTime, "startTime mismatch");
    }

    function test() external override {
        // @dev To avoid this being included in the coverage results
        // https://github.com/foundry-rs/foundry/issues/2988#issuecomment-1437784542
    }
}
