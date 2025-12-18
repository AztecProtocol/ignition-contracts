// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IVirtualAztecToken} from "src/uniswap-periphery/VirtualAztecToken.sol";
import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";
import {VirtualAztecTokenBase} from "../VirtualAztecTokenBase.sol";
import {Ownable} from "@oz/access/Ownable.sol";

contract SetStrategy is VirtualAztecTokenBase {
    function setUp() public override {
        super.setUp();
    }

    function test_whenCallerOfSetStrategyIsNotOwner(address _caller) public {
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        virtualAztecToken.setStrategyAddress(address(1));
    }

    function test_whenStrategyIsTheZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IVirtualAztecToken.VirtualAztecToken__ZeroAddress.selector));

        vm.prank(address(this));
        virtualAztecToken.setStrategyAddress(address(0));
    }

    function test_whenCallerOfSetStrategyIsOwner(address _strategy) public {
        vm.assume(_strategy != address(0));

        vm.expectEmit(true, true, true, true, address(virtualAztecToken));
        emit IVirtualAztecToken.StrategyAddressSet(address(_strategy));
        vm.prank(address(this));
        virtualAztecToken.setStrategyAddress(address(_strategy));

        assertEq(address(virtualAztecToken.strategyAddress()), _strategy);
    }
}
