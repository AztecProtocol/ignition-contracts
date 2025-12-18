// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// Libs
import {Ownable} from "@oz/access/Ownable.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {IERC20Errors} from "@oz/interfaces/draft-IERC6093.sol";

// Test
import {VirtualAztecToken} from "src/uniswap-periphery/VirtualAztecToken.sol";
import {VirtualAztecTokenBase} from "../VirtualAztecTokenBase.sol";

import {console} from "forge-std/console.sol";

contract AztecVirtualTokenMint is VirtualAztecTokenBase {
    function setUp() public override {
        super.setUp();
    }

    function test_whenTheSenderIsNotTheOwner(address _sender) public {
        vm.assume(_sender != address(this));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _sender));
        vm.prank(_sender);
        virtualAztecToken.mint(address(1), 100);
    }

    function test_GivenTheSenderIsTheOwner_WhenTheMinterHasNotApprovedTheUnderlying(uint256 _amount) public {
        // it should revert with ERC20InsufficientAllowance
        vm.assume(_amount != 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(virtualAztecToken), 0, _amount
            )
        );
        virtualAztecToken.mint(address(1), _amount);

        assertEq(virtualAztecToken.totalSupply(), 0);
        assertEq(underlyingToken.balanceOf(address(virtualAztecToken)), 0);
    }

    function test_GivenTheSenderIsTheOwner_WhenTheMintingIsNotBacked1To1ByTheUnderlying(address _to, uint256 _amount)
        public
        view
    {
        // TODO: could enforce as an invariant
        // it should mint the tokens
        vm.assume(_to != address(0));
        vm.assume(_to != address(this));
    }

    function test_GivenTheSenderIsTheOwner_WhenTheMintingIsBacked1To1ByTheUnderlying(address _to, uint256 _amount)
        public
    {
        // it should revert with UnderlyingTokensNotBacked
        vm.assume(_to != address(0));
        vm.assume(_to != address(this));
        vm.assume(_to != address(virtualAztecToken));

        underlyingToken.mint(address(this), _amount);
        underlyingToken.approve(address(virtualAztecToken), _amount);

        virtualAztecToken.mint(_to, _amount);

        assertEq(virtualAztecToken.totalSupply(), _amount);
        assertEq(underlyingToken.balanceOf(address(virtualAztecToken)), _amount);
        assertEq(underlyingToken.balanceOf(_to), 0);

        assertEq(underlyingToken.balanceOf(address(this)), 0);
    }
}
