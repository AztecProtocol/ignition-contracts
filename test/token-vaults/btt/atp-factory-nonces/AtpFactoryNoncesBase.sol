// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Aztec, ATPFactoryNonces} from "test/token-vaults/Importer.sol";

contract ATPFactoryNoncesBase is Test {
    Aztec internal aztec;
    ATPFactoryNonces internal atpFactory;

    function setUp() public virtual {
        aztec = new Aztec(address(this));

        atpFactory = new ATPFactoryNonces(address(this), IERC20(address(aztec)), 100, 100);
        atpFactory.setMinter(address(this), true);

        aztec.mint(address(atpFactory), type(uint128).max);
    }
}
