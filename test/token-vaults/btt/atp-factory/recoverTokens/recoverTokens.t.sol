// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Ownable} from "@oz/access/Ownable.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {MockERC20} from "test/forge-std/mocks/MockERC20.sol";
import {ATPFactory, Aztec} from "test/token-vaults/Importer.sol";

import {ATPFactoryBase} from "../AtpFactoryBase.sol";

contract RecoverTokensTest is ATPFactoryBase {
    IERC20 internal randomToken;

    function setUp() public override {
        super.setUp();

        assertEq(address(aztec), address(atpFactory.getToken()));

        Aztec t = new Aztec(address(this));
        t.mint(address(atpFactory), 1000e18);
        randomToken = IERC20(address(t));
    }

    function test_WhenCallerNEQOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        atpFactory.recoverTokens(address(aztec), address(1), 100);

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        atpFactory.recoverTokens(address(randomToken), address(1), 100);
    }

    function test_WhenCallerEQOwner(uint256 _amount) external {
        // it transfer _amount of tokens to the _to

        uint256 aztecBalance = aztec.balanceOf(address(atpFactory));
        uint256 aztecRecoverAmount = bound(_amount, 1, aztecBalance);

        uint256 randomTokenBalance = randomToken.balanceOf(address(atpFactory));
        uint256 randomTokenRecoverAmount = bound(_amount, 1, randomTokenBalance);

        atpFactory.recoverTokens(address(aztec), address(1), aztecRecoverAmount);
        atpFactory.recoverTokens(address(randomToken), address(1), randomTokenRecoverAmount);

        assertEq(aztec.balanceOf(address(1)), aztecRecoverAmount);
        assertEq(aztec.balanceOf(address(atpFactory)), aztecBalance - aztecRecoverAmount);

        assertEq(randomToken.balanceOf(address(1)), randomTokenRecoverAmount);
        assertEq(randomToken.balanceOf(address(atpFactory)), randomTokenBalance - randomTokenRecoverAmount);
    }
}
