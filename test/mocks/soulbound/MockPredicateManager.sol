// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Task} from "@predicate/interfaces/IPredicateManager.sol";

contract MockPredicateManager {
    mapping(string policyID => bool) public policies;
    mapping(address sender => string policyID) public policyIDs;
    mapping(string policyID => bool response) public mockPolicyResponses;

    function setPolicyResponse(string memory _policyID, bool _response) external {
        mockPolicyResponses[_policyID] = _response;
    }

    function deployPolicy(string memory _policyID, string memory _policy, uint256 _quorumThreshold) external {
        // Set that the policy ID exists
        policies[_policyID] = true;
    }

    function validateSignatures(Task memory _task, address[] memory _signerAddresses, bytes[] memory _signatures)
        external
        view
        returns (bool isVerified)
    {
        string memory expectedPolicyID = policyIDs[msg.sender];
        string memory policyID = _task.policyID;

        require(
            keccak256(abi.encodePacked(expectedPolicyID)) == keccak256(abi.encodePacked(policyID)), "Invalid policy ID"
        );
        return mockPolicyResponses[policyID];
    }

    function setPolicy(string memory _policyID) external {
        policyIDs[msg.sender] = _policyID;
    }
}
