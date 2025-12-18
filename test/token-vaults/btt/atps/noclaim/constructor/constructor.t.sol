// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {NCATPTestBase} from "test/token-vaults/ncatp_base.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {NCATP, IATPCore, IRegistry, ATPType} from "test/token-vaults/Importer.sol";

contract ConstructorTest is NCATPTestBase {
    function test_WhenRegistryEQAddressZero() external {
        // it revert
        vm.expectRevert(abi.encodeWithSelector(IATPCore.InvalidRegistry.selector, address(0)));
        new NCATP(IRegistry(address(0)), IERC20(address(0)));
    }

    modifier whenRegistryNEQAddressZero() {
        _;
    }

    function test_WhenTokenEQAddressZero() external whenRegistryNEQAddressZero {
        // it revert
        vm.expectRevert(abi.encodeWithSelector(IATPCore.InvalidTokenAddress.selector, address(0)));
        new NCATP(IRegistry(address(1)), IERC20(address(0)));
    }

    function test_WhenTokenNEQAddressZero() external whenRegistryNEQAddressZero {
        // it updates the TOKEN
        // it updates the REGISTRY
        NCATP atp = new NCATP(IRegistry(address(1)), IERC20(address(2)));

        assertEq(address(atp.getRegistry()), address(1));
        assertEq(address(atp.getToken()), address(2));
        assertTrue(atp.getType() == ATPType.NonClaim);
    }
}
