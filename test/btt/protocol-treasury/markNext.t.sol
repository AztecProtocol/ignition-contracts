// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.27;

import {ProposalState, Proposal} from "@aztec/governance/interfaces/IGovernance.sol";

import {ProtocolTreasury, IProtocolTreasury} from "src/ProtocolTreasury.sol";

import {TreasuryTestBase} from "./base.sol";

contract markNextTest is TreasuryTestBase {
    uint256 internal count;
    uint256 internal indexOfInterest;

    function test_WhenProposalIdGEProposalCount(uint256 _count) external {
        // it reverts {NoProposalToMark}

        // Adds between 0 and 16 "proposals" that have all passed to ensure reverts if moving beyond
        count = bound(_count, 0, 16);
        governance.setProposalCount(count);
        for (uint256 i = 0; i < count; i++) {
            governance.setProposalState(i, ProposalState.Executed);
            treasury.markNext();
        }

        vm.expectRevert(abi.encodeWithSelector(IProtocolTreasury.NoProposalToMark.selector));
        treasury.markNext();
    }

    modifier whenProposalIdLTProposalCount(uint256 _count, uint256 _indexOfInterest, uint256[16] memory _seeds) {
        // Will create a number of proposals before the one we check that are all "dead".
        count = bound(_count, 1, 16);
        indexOfInterest = bound(_indexOfInterest, 0, count - 1);

        governance.setProposalCount(count);
        for (uint256 i; i < indexOfInterest; i++) {
            governance.setProposalState(i, _getDeadState(_seeds[i]));

            uint256 before = treasury.markedProposalsCount();

            vm.expectEmit(true, true, true, true, address(treasury));
            emit IProtocolTreasury.ProposalMarked(i);
            treasury.markNext();

            assertEq(treasury.markedProposalsCount(), before + 1, "Marked proposal count not increased");
        }

        _;
    }

    function test_WhenProposalStateIsAlive(uint256 _count, uint256 _aliveIndex, uint256[16] memory _seeds)
        external
        whenProposalIdLTProposalCount(_count, _aliveIndex, _seeds)
    {
        // It reverts with {ProposalIsAlive}

        governance.setProposalState(indexOfInterest, _getAliveState(_seeds[indexOfInterest]));

        // This is the point where the proposal get interesting.
        vm.expectRevert(abi.encodeWithSelector(IProtocolTreasury.ProposalIsAlive.selector));
        treasury.markNext();
    }

    function test_WhenProposalStateIsDead(
        uint256 _count,
        uint256 _aliveIndex,
        uint256[16] memory _seeds,
        uint256 _blockNumber
    ) external whenProposalIdLTProposalCount(_count, _aliveIndex, _seeds) {
        // it increases markedProposalsCount
        // it set blockOfLastMarkNext to block number
        // it emits {ProposalMarked}

        vm.roll(_blockNumber);

        governance.setProposalState(indexOfInterest, _getDeadState(_seeds[indexOfInterest]));

        uint256 before = treasury.markedProposalsCount();

        vm.expectEmit(true, true, true, true, address(treasury));
        emit IProtocolTreasury.ProposalMarked(indexOfInterest);
        treasury.markNext();

        assertEq(treasury.markedProposalsCount(), before + 1, "Marked proposal count not increased");
        assertEq(treasury.blockOfLastMarkNext(), _blockNumber, "Block number not updated");
    }
}
