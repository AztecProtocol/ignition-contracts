// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {NCATPTestBase} from "test/token-vaults/ncatp_base.sol";
import {INCATP, ATPType, RevokableParams, LockParams} from "test/token-vaults/Importer.sol";

contract GetTypeTest is NCATPTestBase {
    function test_ReturnsATPTypeNonClaim() external {
        // it returns ATPType.NonClaim
        RevokableParams memory revokableParams = RevokableParams({
            revokeBeneficiary: address(0), lockParams: LockParams({startTime: 0, cliffDuration: 0, lockDuration: 0})
        });

        INCATP atp = atpFactory.createNCATP(address(1), 1000e18, revokableParams);
        assertEq(uint8(atp.getType()), uint8(ATPType.NonClaim));
    }
}
