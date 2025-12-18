// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {IWhitelistProvider} from "src/soulbound/providers/IWhitelistProvider.sol";
import {ZKPassportBase} from "../ZKPassportBase.sol";
import {Ownable} from "@oz/access/Ownable.sol";

// solhint-disable comprehensive-interface
// solhint-disable func-name-mixedcase
// solhint-disable ordering

contract ZKPassportPortNullifiersTest is ZKPassportBase {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerOfPortNullifiersIsNotOwner(address _caller) external {
        // it reverts
        vm.assume(_caller != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        zkPassportProvider.portNullifiers(new bytes32[](0));
    }

    function test_WhenCallerOfPortNullifiersIsOwner(bytes32[] memory _nullifiers) external {
        // it adds nullifiers to nullifier hashes mapping
        vm.assume(_nullifiers.length > 0);
        zkPassportProvider.portNullifiers(_nullifiers);

        for (uint256 i = 0; i < _nullifiers.length; i++) {
            assertTrue(zkPassportProvider.nullifierHashes(_nullifiers[i]));
        }
    }
}
