// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {LockParams, RevokableParams} from "test/token-vaults/Importer.sol";
import {LATPInvariantTest} from "./LATPInvariant.sol";

contract InvariantEQAccumTest is LATPInvariantTest {
    function deploy() internal virtual override {
        atp = atpFactory.createLATP(
            address(handler),
            allocation,
            RevokableParams({
                revokeBeneficiary: revokeBeneficiary,
                lockParams: LockParams({startTime: unlockStartTime, cliffDuration: 250, lockDuration: 1000})
            })
        );

        assertTrue(
            isLockEq(atp.getGlobalLock(), atp.getAccumulationLock()), "Global lock and accumulation lock are not equal"
        );
    }

    function test() external override {
        // @dev To avoid this being included in the coverage results
        // https://github.com/foundry-rs/foundry/issues/2988#issuecomment-1437784542
    }
}
