// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {ERC1967Proxy} from "@oz/proxy/ERC1967/ERC1967Proxy.sol";
import {Test} from "forge-std/Test.sol";
import {BaseStaker} from "test/token-vaults/Importer.sol";

contract InitializeTest is Test {
    BaseStaker public proxy;

    function setUp() public {
        BaseStaker baseStaker = new BaseStaker();

        // Run without initializing it.
        proxy = BaseStaker(address(new ERC1967Proxy(address(baseStaker), "")));
    }

    function test_WhenAtpEQZero() public {
        vm.expectRevert(abi.encodeWithSelector(BaseStaker.ZeroATP.selector));
        proxy.initialize(address(0));
    }

    function test_AlreadyInitialized() public {
        proxy.initialize(address(1));

        vm.expectRevert(abi.encodeWithSelector(BaseStaker.AlreadyInitialized.selector));
        proxy.initialize(address(1));
    }
}
