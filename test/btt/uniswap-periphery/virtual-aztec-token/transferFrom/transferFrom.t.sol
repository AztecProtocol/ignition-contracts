// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {VirtualAztecTokenBase} from "../VirtualAztecTokenBase.sol";
import {IVirtualAztecToken} from "src/uniswap-periphery/VirtualAztecToken.sol";

contract TransferFromTest is VirtualAztecTokenBase {
    function setUp() public override {
        super.setUp();
    }

    function test_When_toNEQStrategyAddress(address _caller, address _to, uint256 _amount) external {
        // it reverts with {VirtualAztecToken__NotImplemented}
        vm.assume(_caller != address(strategy));
        vm.assume(_to != address(strategy));

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(IVirtualAztecToken.VirtualAztecToken__NotImplemented.selector));
        virtualAztecToken.transferFrom(_caller, _to, _amount);
    }

    function test_When_toEQStrategyAddress(address _caller, address _launcher, uint256 _amount) external {
        // it succeeds

        vm.assume(_caller != address(0) && _caller != address(strategy));
        vm.assume(_launcher != address(0));
        vm.assume(_amount > 0);

        __helper__mint(_caller, _amount);

        assertEq(virtualAztecToken.balanceOf(_caller), _amount);

        vm.prank(_caller);
        virtualAztecToken.approve(_launcher, _amount);

        vm.prank(_launcher);
        bool success = virtualAztecToken.transferFrom(_caller, address(strategy), _amount);
        assertTrue(success);

        assertEq(virtualAztecToken.balanceOf(_caller), 0);
        assertEq(virtualAztecToken.balanceOf(address(strategy)), _amount);
    }
}
