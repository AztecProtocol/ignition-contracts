// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {LockParams, RevokableParams} from "test/token-vaults/Importer.sol";
import {LATPInvariantTest} from "./LATPInvariant.sol";

/**
 * @notice  Test where there are 2 curves, the global lock and the accumulation
 *          The curves are here defined as the same, so we can simple use the values of the
 *          unlock throughout. Practically the same test as the non-revokable just with 2 curves
 */
contract InvariantFastAccumEarlyTest is LATPInvariantTest {
    function setUp() public override {
        // We start the unlock in 125 seconds, so it starts later than the accumulation lock
        unlockStartTime = block.timestamp + 125;
        super.setUp();
    }

    function deploy() internal virtual override {
        atp = atpFactory.createLATP(
            address(handler),
            allocation,
            RevokableParams({
                revokeBeneficiary: revokeBeneficiary,
                lockParams: LockParams({startTime: block.timestamp, cliffDuration: 200, lockDuration: 500})
            })
        );

        assertGt(atp.getGlobalLock().startTime, atp.getAccumulationLock().startTime, "startTime mismatch");
    }

    function test() external override {
        // @dev To avoid this being included in the coverage results
        // https://github.com/foundry-rs/foundry/issues/2988#issuecomment-1437784542
    }
}
