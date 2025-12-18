// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {SoulboundBase} from "../SoulboundBase.t.sol";
import {Ownable} from "@oz/access/Ownable.sol";

contract SetGenesisSequencerMerkleRoot is SoulboundBase {
    function setUp() public override {
        super.setUp();
    }

    function test_shouldSetGenesisSequencerMerkleRootWhenCallerIsOwner(bytes32 _newRoot) public {
        vm.expectEmit(true, true, true, true);
        emit IIgnitionParticipantSoulbound.GenesisSequencerMerkleRootUpdated(_newRoot);
        soulboundToken.setGenesisSequencerMerkleRoot(_newRoot);

        assertEq(soulboundToken.genesisSequencerMerkleRoot(), _newRoot);
    }

    function test_shouldRevertWhenCallerIsNotOwner(bytes32 _newRoot, address _caller) public {
        vm.assume(_caller != address(this));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);
        soulboundToken.setGenesisSequencerMerkleRoot(_newRoot);
    }
}
