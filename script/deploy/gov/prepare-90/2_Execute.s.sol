// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {Governance} from "@aztec/governance/Governance.sol";
import {Prepare90Base} from "./Prepare90Base.sol";

contract ExecuteProposal is Prepare90Base {
    function run() public {
        string memory json = _loadJson();

        Governance governance = Governance(vm.parseJsonAddress(json, ".governanceAddress"));
        uint256 proposalId = governance.proposalCount() - 1;

        vm.broadcast();
        governance.execute(proposalId);
    }
}