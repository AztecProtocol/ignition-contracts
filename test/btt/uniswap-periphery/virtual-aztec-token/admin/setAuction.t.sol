// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IVirtualAztecToken} from "src/uniswap-periphery/VirtualAztecToken.sol";
import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";
import {VirtualAztecTokenBase} from "../VirtualAztecTokenBase.sol";
import {Ownable} from "@oz/access/Ownable.sol";

contract SetAuction is VirtualAztecTokenBase {
    function setUp() public override {
        super.setUp();
    }

    function test_whenCallerOfSetAuctionIsNotOwner(address _caller) public {
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        virtualAztecToken.setAuctionAddress(IContinuousClearingAuction(address(1)));
    }

    function test_whenAuctionIsTheZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IVirtualAztecToken.VirtualAztecToken__ZeroAddress.selector));

        vm.prank(address(this));
        virtualAztecToken.setAuctionAddress(IContinuousClearingAuction(address(0)));
    }

    function test_whenCallerOfSetAuctionIsOwner(address _auction) public {
        vm.assume(_auction != address(0));

        vm.expectEmit(true, true, true, true, address(virtualAztecToken));
        emit IVirtualAztecToken.AuctionAddressSet(IContinuousClearingAuction(_auction));
        vm.prank(address(this));
        virtualAztecToken.setAuctionAddress(IContinuousClearingAuction(_auction));
    }
}
