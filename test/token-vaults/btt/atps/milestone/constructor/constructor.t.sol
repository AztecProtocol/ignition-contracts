// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {MATPTestBase} from "test/token-vaults/matp_base.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {MATP, IATPCore, IRegistry, ATPType} from "test/token-vaults/Importer.sol";

contract ConstructorTest is MATPTestBase {
    function test_WhenTokenEQAddressZero() external {
        // it revert
        vm.expectRevert(abi.encodeWithSelector(IATPCore.InvalidRegistry.selector, address(0)));
        new MATP(IRegistry(address(0)), IERC20(address(0)));
    }

    modifier whenTokenNEQAddressZero() {
        _;
    }

    function test_WhenRegistryEQAddressZero() external whenTokenNEQAddressZero {
        // it revert
        vm.expectRevert(abi.encodeWithSelector(IATPCore.InvalidTokenAddress.selector, address(0)));
        new MATP(IRegistry(address(1)), IERC20(address(0)));
    }

    function test_WhenRegistryNEQAddressZero() external whenTokenNEQAddressZero {
        // it updates the TOKEN
        // it updates the REGISTRY
        MATP atp = new MATP(IRegistry(address(1)), IERC20(address(2)));

        assertEq(address(atp.getRegistry()), address(1));
        assertEq(address(atp.getToken()), address(2));
        assertTrue(atp.getType() == ATPType.Milestone);
    }
}
