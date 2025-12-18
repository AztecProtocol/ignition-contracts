// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {NCATPTestBase} from "test/token-vaults/ncatp_base.sol";
import {INCATP, IATPCore, RevokableParams, LockParams} from "test/token-vaults/Importer.sol";

contract ClaimTest is NCATPTestBase {
    INCATP internal atp;
    address internal beneficiary = address(bytes20("beneficiary"));

    function setUp() public override {
        super.setUp();

        RevokableParams memory revokableParams = RevokableParams({
            revokeBeneficiary: address(0), lockParams: LockParams({startTime: 0, cliffDuration: 0, lockDuration: 0})
        });

        atp = atpFactory.createNCATP(beneficiary, 1000e18, revokableParams);
    }

    function test_WhenCallerNEQBeneficiary(address _caller) external {
        // it reverts NotBeneficiary
        vm.assume(_caller != beneficiary);

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IATPCore.NotBeneficiary.selector, _caller, beneficiary));
        atp.claim();
    }

    function test_WhenCallerEQBeneficiary() external {
        // it reverts NoClaimable
        vm.prank(beneficiary);
        vm.expectRevert(IATPCore.NoClaimable.selector);
        atp.claim();
    }
}
