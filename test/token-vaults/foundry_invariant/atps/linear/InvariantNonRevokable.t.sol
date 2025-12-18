// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {LockLib, RevokableParams} from "test/token-vaults/Importer.sol";
import {LATPInvariantTest} from "./LATPInvariant.sol";

contract InvariantNonRevokableTest is LATPInvariantTest {
    function deploy() internal virtual override {
        atp = atpFactory.createLATP(
            address(handler), allocation, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
        );
    }

    function extraChecks() internal view override {
        assertEq(atp.getIsRevokable(), false, "LATP is revokable");
        assertEq(token.balanceOf(registry.getRevoker()), 0, "Revoker has balance");
    }

    function test() external override {
        // @dev To avoid this being included in the coverage results
        // https://github.com/foundry-rs/foundry/issues/2988#issuecomment-1437784542
    }
}
