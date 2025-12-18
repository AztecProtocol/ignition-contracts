// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Internal
import {AztecAuctionHook, IAztecAuctionHook} from "src/uniswap-periphery/AuctionHook.sol";
import {IgnitionParticipantSoulbound} from "src/soulbound/IgnitionParticipantSoulbound.sol";

// Mocks
import {MockAuction} from "test/mocks/uniswap-periphery/MockAuction.sol";

// Uniswap
import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";

// Libs
import {Ownable} from "@oz/access/Ownable.sol";

// Test
import {Test} from "forge-std/Test.sol";

contract SetAuction is Test {
    AztecAuctionHook internal auctionHook;
    IgnitionParticipantSoulbound internal soulbound;
    IContinuousClearingAuction internal auction;

    function setUp() public {
        soulbound = new IgnitionParticipantSoulbound(
            address(this), new address[](0), bytes32(0), bytes32(0), address(1), "https://aztec.network"
        );

        auction = IContinuousClearingAuction(address(new MockAuction()));
        uint256 contributorPeriodBlockEnd = block.number + 100;
        auctionHook = new AztecAuctionHook(soulbound, contributorPeriodBlockEnd);
    }

    function test_whenCallerOfSetAuctionIsNotOwner(address _caller) public {
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        auctionHook.setAuction(IContinuousClearingAuction(address(1)));
    }

    function test_whenCallerOfSetAuctionIsOwner(address _auction) public {
        vm.assume(_auction != address(0));
        vm.expectEmit(true, true, true, true, address(auctionHook));
        emit IAztecAuctionHook.AuctionSet(_auction);
        vm.prank(address(this));
        auctionHook.setAuction(IContinuousClearingAuction(_auction));

        assertEq(address(auctionHook.auction()), _auction);
    }
}
