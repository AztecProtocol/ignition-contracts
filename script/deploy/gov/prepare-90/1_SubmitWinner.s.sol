// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {GovernanceProposer} from "@aztec/governance/proposer/GovernanceProposer.sol";
import {Prepare90Base} from "./Prepare90Base.sol";

contract SubmitWinner is Prepare90Base {
    function run() public {
        string memory json = _loadJson();

        GovernanceProposer proposer = GovernanceProposer(vm.parseJsonAddress(json, ".governanceProposerAddress"));
        uint256 currentRound = proposer.getCurrentRound();

        vm.broadcast();
        proposer.submitRoundWinner(currentRound);
    }
}