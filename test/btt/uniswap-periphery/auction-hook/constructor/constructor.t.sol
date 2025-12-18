// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {AztecAuctionHook} from "src/uniswap-periphery/AuctionHook.sol";
import {IAztecAuctionHook} from "src/uniswap-periphery/AuctionHook.sol";
import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {Test} from "forge-std/Test.sol";

contract AztecAuctionHookConstructor is Test {
    function test_whenSoulboundEQAddressZero() public {
        // it reverts
        vm.expectRevert(abi.encodeWithSelector(IAztecAuctionHook.AztecAuctionHook__ZeroAddress.selector));
        new AztecAuctionHook(IIgnitionParticipantSoulbound(address(0)), block.number + 100);
    }

    function test_whenContributorPeriodBlockEndLTBlockNumber(uint32 _nowBlockNumber, uint32 _contributorPeriodBlockEnd)
        public
    {
        vm.assume(_contributorPeriodBlockEnd < _nowBlockNumber);

        vm.roll(_nowBlockNumber);

        // it reverts
        vm.expectRevert(
            abi.encodeWithSelector(IAztecAuctionHook.AztecAuctionHook__ContributorPeriodEndBlockInPast.selector)
        );
        new AztecAuctionHook(IIgnitionParticipantSoulbound(address(1)), _contributorPeriodBlockEnd);
    }

    function test_whenAllParametersAreValid(
        uint32 _nowBlockNumber,
        uint32 _contributorPeriodBlockEnd,
        address _soulbound,
        address _auction
    ) public {
        vm.assume(_contributorPeriodBlockEnd > _nowBlockNumber);
        vm.assume(_soulbound != address(0));
        vm.assume(_auction != address(0));

        vm.roll(_nowBlockNumber);

        AztecAuctionHook auctionHook =
            new AztecAuctionHook(IIgnitionParticipantSoulbound(address(_soulbound)), _contributorPeriodBlockEnd);

        assertEq(address(auctionHook.SOULBOUND()), _soulbound);
        assertEq(auctionHook.CONTRIBUTOR_PERIOD_END_BLOCK(), _contributorPeriodBlockEnd);
        assertEq(auctionHook.MAX_PURCHASE_LIMIT(), 250 ether);
    }
}
