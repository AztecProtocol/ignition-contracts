import {Script} from "forge-std/Script.sol";
import {MerkleTreeGetters} from "test/merkle-tree/merkle_tree_getters.sol";
import {IgnitionParticipantSoulbound} from "src/soulbound/IgnitionParticipantSoulbound.sol";

pragma solidity ^0.8.27;

contract UpdateWhitelists is MerkleTreeGetters, Script {
    address constant soulbound = 0xde3aBf41Bd70787A5D17a490b3D280D046a0a79F;

    function run() public {
        // Get the merkle roots for the genesis sequencer - requires yarn process-merkle-tree to be run beforehand
        bytes32 genesisSequencerMerkleRoot = getRoot(MerkleTreeType.GenesisSequencer);
        bytes32 contributorMerkleRoot = getRoot(MerkleTreeType.Contributor);

        vm.startBroadcast();
        IgnitionParticipantSoulbound(soulbound).setGenesisSequencerMerkleRoot(genesisSequencerMerkleRoot);
        IgnitionParticipantSoulbound(soulbound).setContributorMerkleRoot(contributorMerkleRoot);
        vm.stopBroadcast();
    }
}
