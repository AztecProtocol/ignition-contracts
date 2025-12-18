// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {IATPFactory, ATPFactoryNonces, Aztec} from "test/token-vaults/Importer.sol";

contract SetMinterNoncesTest is Test {
    Aztec internal aztec;
    ATPFactoryNonces internal atpFactory;

    address internal newMinter = address(0x123);

    function setUp() external {
        aztec = new Aztec(address(this));
        atpFactory = new ATPFactoryNonces(address(this), IERC20(address(aztec)), 100, 100);
    }

    function test_WhenCallerNEQOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        atpFactory.setMinter(newMinter, true);
    }

    modifier whenCallerEQOwner() {
        _;
    }

    function test_WhenSettingMinterToTrue() external whenCallerEQOwner {
        // it sets the minter mapping to true
        // it emits MinterSet event

        assertFalse(atpFactory.minter(newMinter));

        vm.expectEmit(true, true, true, true);
        emit IATPFactory.MinterSet(newMinter, true);
        atpFactory.setMinter(newMinter, true);

        assertTrue(atpFactory.minter(newMinter));
    }

    function test_WhenSettingMinterToFalse() external whenCallerEQOwner {
        // it sets the minter mapping to false
        // it emits MinterSet event

        // First set to true
        atpFactory.setMinter(newMinter, true);
        assertTrue(atpFactory.minter(newMinter));

        // Then set to false
        vm.expectEmit(true, true, true, true);
        emit IATPFactory.MinterSet(newMinter, false);
        atpFactory.setMinter(newMinter, false);

        assertFalse(atpFactory.minter(newMinter));
    }
}
