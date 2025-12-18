// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.27;

import {Test} from "forge-std/Test.sol";
import {ProposalState, Proposal} from "@aztec/governance/interfaces/IGovernance.sol";
import {ProtocolTreasury, IProtocolTreasury} from "src/ProtocolTreasury.sol";

contract FakeGovernance {
    mapping(uint256 id => ProposalState proposalState) internal states;
    mapping(uint256 id => Proposal proposal) internal proposals;
    uint256 public proposalCount;

    function setProposalCount(uint256 _count) external {
        proposalCount = _count;
    }

    function setProposalState(uint256 proposalId, ProposalState state) external {
        states[proposalId] = state;
    }

    function setProposal(uint256 proposalId, Proposal memory _proposal, ProposalState _state) external {
        states[proposalId] = _state;
        proposals[proposalId] = _proposal;
    }

    function getProposalState(uint256 id) external view returns (ProposalState) {
        return states[id];
    }

    function getProposal(uint256 id) external view returns (Proposal memory) {
        return proposals[id];
    }
}

contract FakeAtpRegistry {
    uint256 public getExecuteAllowedAt;

    function setExecuteAllowedAt(uint256 a) external {
        getExecuteAllowedAt = a;
    }
}

contract TreasuryTestBase is Test {
    FakeGovernance internal governance; // = makeAddr("governance");
    FakeAtpRegistry internal atpRegistry; // = makeAddr("atp_registry");
    ProtocolTreasury internal treasury;

    function setUp() external {
        governance = new FakeGovernance();
        atpRegistry = new FakeAtpRegistry();

        treasury = new ProtocolTreasury({
            _governance: address(governance),
            _atpRegistry: address(atpRegistry),
            _gatedUntil: block.timestamp + 365 days
        });
    }

    function _getDeadState(uint256 _seed) internal pure returns (ProposalState) {
        ProposalState[4] memory deadStates =
            [ProposalState.Rejected, ProposalState.Executed, ProposalState.Dropped, ProposalState.Expired];
        return deadStates[bound(_seed, 0, deadStates.length - 1)];
    }

    function _getAliveState(uint256 _seed) internal pure returns (ProposalState) {
        ProposalState[5] memory aliveStates = [
            ProposalState.Pending,
            ProposalState.Active,
            ProposalState.Queued,
            ProposalState.Executable,
            ProposalState.Droppable
        ];
        return aliveStates[bound(_seed, 0, aliveStates.length - 1)];
    }
}
