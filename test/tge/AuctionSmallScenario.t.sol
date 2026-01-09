// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TGEPayload} from "src/tge/TGEPayload.sol";

import {LATP} from "src/token-vaults/atps/linear/LATP.sol";
import {Governance} from "@aztec/governance/Governance.sol";
import {IATPCore} from "src/token-vaults/atps/linear/ILATP.sol";

import {Base} from "./Base.sol";

contract AuctionSmallScenarioTest is Base {
    // Small scenario tests for the small holders of the auction, e.g., people with
    // less than 200K tokens that are unable to stake. This is the LATP holders.

    LATP public SMALL_HOLDER_LATP = LATP(0xf855E9d895c8734b99f4f032BFbb5a703736A424);

    function test_small_holder_cannot_claim() public {
        address beneficiary = SMALL_HOLDER_LATP.getBeneficiary();
        vm.expectRevert(abi.encodeWithSelector(IATPCore.NoClaimable.selector));
        vm.prank(beneficiary);
        SMALL_HOLDER_LATP.claim();
    }

    function test_small_holder_can_claim() public {
        proposeAndExecuteProposal();

        address beneficiary = SMALL_HOLDER_LATP.getBeneficiary();

        uint256 balanceBefore = AZTEC_TOKEN.balanceOf(beneficiary);
        uint256 latpBalanceBefore = AZTEC_TOKEN.balanceOf(address(SMALL_HOLDER_LATP));
        assertGt(latpBalanceBefore, 0);

        vm.prank(beneficiary);
        SMALL_HOLDER_LATP.claim();

        uint256 balanceAfter = AZTEC_TOKEN.balanceOf(beneficiary);
        uint256 latpBalanceAfter = AZTEC_TOKEN.balanceOf(address(SMALL_HOLDER_LATP));

        assertEq(balanceAfter, balanceBefore + latpBalanceBefore);
        assertEq(latpBalanceAfter, 0);
    }
}
