// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {MerkleTreeGetters} from "test/merkle-tree/merkle_tree_getters.sol";
import {IgnitionParticipantSoulbound} from "src/soulbound/IgnitionParticipantSoulbound.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";

pragma solidity ^0.8.28;

contract AdminMintToken is MerkleTreeGetters, Script {
    address constant soulbound = 0x53B56885ADfBc566c42E4822f9b32802599638D6;

    function run() public {
        // Get the merkle roots for the genesis sequencer - requires yarn process-merkle-tree to be run beforehand
        uint256 gridTileId = 1; // TODO: must be a proper id
        address[] memory addresses = new address[](0);
        // addresses[0] = 0x763F31c28f2cc0a753E22c449d28b5EcBB6D3E7a;

        vm.startBroadcast();
        for (uint256 i = 0; i < addresses.length; i++) {
            IgnitionParticipantSoulbound(soulbound)
                .adminMint(addresses[i], IIgnitionParticipantSoulbound.TokenId.CONTRIBUTOR, gridTileId);
        }
        vm.stopBroadcast();
    }
}
