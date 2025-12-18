// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Aztec Labs.
pragma solidity >=0.8.27;

import {ProposalState, Proposal} from "@aztec/governance/interfaces/IGovernance.sol";
import {Governance} from "@aztec/governance/Governance.sol";
import {Timestamp} from "@aztec/shared/libraries/TimeMath.sol";
import {IRegistry} from "@atp/Registry.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {Address} from "@oz/utils/Address.sol";
import {Errors} from "@oz/utils/Errors.sol";

interface IProtocolTreasury {
    error GateIsClosed(string reason);
    error ProposalIsAlive();
    error NoProposalToMark();

    event ProposalMarked(uint256 indexed proposalId);

    function markNext() external;
    function relay(address target, bytes calldata data, uint256 value) external returns (bytes memory);
    function getActivationTimestamp() external view returns (uint256);
    function owner() external view returns (address);
}

/**
 * @title   ProtocolTreasury
 * @author  Aztec Labs
 * @notice  A non-transferable date gated relayer that further restrict calls such that they can only be relayed if
 *          a specified atp-registry allows execution in the related ATP's.
 *
 *          Example usage is for ownership of contracts that becomes property of the governance at some point
 *          in the future when a group of ATP's can participate.
 *
 *          NOTE: because it is non-transferable it does not work well with governance upgrading itself before relays
 *          are allowed.
 *
 *          NOTE: governance can "DOS" this relayer temporarily by extending the delays of governance. This would
 *          temporarily impact the liveness, but as the delay configuration is bounded it cannot be forever.
 */
contract ProtocolTreasury is IProtocolTreasury {
    Governance public immutable GOVERNANCE;
    IRegistry public immutable ATP_REGISTRY;
    uint256 public immutable GATED_UNTIL;

    uint256 public markedProposalsCount;
    uint256 public blockOfLastMarkNext;

    constructor(address _governance, address _atpRegistry, uint256 _gatedUntil) {
        GOVERNANCE = Governance(_governance);
        ATP_REGISTRY = IRegistry(_atpRegistry);
        GATED_UNTIL = _gatedUntil;
    }

    /**
     * @notice  Marks the next proposal if "stable"
     *          Used to progress the list of proposals forward to satisfy checks in relay
     *
     * @dev     Reverts if there are no "unmarked" proposals
     * @dev     Reverts if the proposal is neither EXECUTED | EXPIRED | DROPPED | REJECTED
     *          Essentially, if the state can still change, it is seen as alive.
     */
    function markNext() external override(IProtocolTreasury) {
        uint256 proposalId = markedProposalsCount;
        require(proposalId < GOVERNANCE.proposalCount(), NoProposalToMark());
        ProposalState state = GOVERNANCE.getProposalState(proposalId);

        // state should be either Executed | Expired | Droppped | Reject
        // if that is not the case, it might still be an active proposal and should wait
        require(
            state == ProposalState.Executed || state == ProposalState.Expired || state == ProposalState.Dropped
                || state == ProposalState.Rejected,
            ProposalIsAlive()
        );

        markedProposalsCount++;
        blockOfLastMarkNext = block.number;

        emit ProposalMarked(proposalId);
    }

    /**
     * @notice  Relays the call and potentially transfer ether from self
     *
     * @dev     Reverts if caller is not owner
     * @dev     Reverts if called before GATED_UNTIL
     * @dev     Reverts if called after markNext in the same block
     * @dev     Reverts if the oldest unmarked proposal was created before treasury became active
     *
     * @param target - The address to call
     * @param data - The calldata for the call
     * @param value - The amount of ether (in wei) to forward
     *
     * @return The return value of the function call (as bytes)
     */
    function relay(address target, bytes calldata data, uint256 value)
        external
        override(IProtocolTreasury)
        returns (bytes memory)
    {
        require(msg.sender == address(GOVERNANCE), Ownable.OwnableUnauthorizedAccount(msg.sender));
        require(block.timestamp >= GATED_UNTIL, GateIsClosed("gated until not met"));

        // We do NOT allow `markNext()` to happen in the same block as `isOpen` because that could allow a
        // governance proposal to be marked during its execution. Which could be used to make `isOpen` pass
        // even though we are in the middle of an execution that was made BEFORE insiders could act.
        require(block.number > blockOfLastMarkNext, GateIsClosed("markNext called this block"));

        // The only way `governance` can make a `relay` call is through a proposal. If all proposals are marked
        // the all already have happened, and there is nothing to execute.
        // This is implicitly covered by the creation check, as non-existing proposals have creation time 0, which will
        // never be bigger than another uint.
        //
        // Since time always marches forward, if a proposal is made AFTER getActivationTimestamp, then so are
        // all proposals following it. This means that as soon as as `markedProposalsCount` will be the index of a
        // proposal that was created AFTER the getActivationTimestamp there are no need to mark any other proposals
        // as it will keep being true.
        require(
            GOVERNANCE.getProposal(markedProposalsCount).creation > Timestamp.wrap(getActivationTimestamp()),
            GateIsClosed("not activated yet")
        );

        // Using a mix of low-level calls and OZ lib to handle transfers to non-contracts and easily bubble up.
        require(value == 0 || address(this).balance >= value, Errors.InsufficientBalance(address(this).balance, value));
        (bool success, bytes memory returnData) = payable(target).call{value: value}(data);
        return Address.verifyCallResult(success, returnData);
    }

    /**
     * @notice Allows receiving ether
     */
    receive() external payable {}

    /**
     * @notice  The timestamp where the treasury becomes active
     *
     * @return  Timestamp where treasury can relay
     */
    function getActivationTimestamp() public view override(IProtocolTreasury) returns (uint256) {
        return ATP_REGISTRY.getExecuteAllowedAt() + 7 days;
    }

    /**
     * @notice  Returns the owner (governance)
     *
     * @dev     Exists to make the contract align better with other relayers
     *
     * @return  The address of the governance
     */
    function owner() external view override(IProtocolTreasury) returns (address) {
        return address(GOVERNANCE);
    }
}
