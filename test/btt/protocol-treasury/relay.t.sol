// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.27;

import {ProposalState, Proposal} from "@aztec/governance/interfaces/IGovernance.sol";

import {ProtocolTreasury, IProtocolTreasury} from "src/ProtocolTreasury.sol";
import {TreasuryTestBase} from "./base.sol";

import {Ownable} from "@oz/access/Ownable.sol";
import {Math} from "@oz/utils/math/Math.sol";
import {Timestamp} from "@aztec/shared/libraries/TimeMath.sol";
import {Errors} from "@oz/utils/Errors.sol";

contract Yeeter {
    string public freeMessage;
    string public paidMessage;

    function setMessage(string memory _message) external {
        freeMessage = _message;
    }

    function payToYeet(string memory _message) external payable {
        paidMessage = _message;
    }

    function claimYeetMoney() external {
        (bool success,) = payable(msg.sender).call{value: address(this).balance / 2}("");
        require(success, "oh no");
    }
}

contract relayTest is TreasuryTestBase {
    address internal caller;
    Yeeter internal yeeter = new Yeeter();

    function test_WhenCallerNEQGovernance(address _caller) external {
        // it reverts {GateIsClosed}

        vm.assume(caller != treasury.owner());

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        vm.prank(_caller);

        treasury.relay(address(1), "", 0);
    }

    modifier whenCallerEQGovernance() {
        caller = treasury.owner();
        _;
    }

    function test_WhenTimestampLTGatedUntil(uint256 _time) external whenCallerEQGovernance {
        // it reverts {GateIsClosed}

        uint256 time = bound(_time, block.timestamp, treasury.GATED_UNTIL() - 1);
        vm.warp(time);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(IProtocolTreasury.GateIsClosed.selector, "gated until not met"));
        treasury.relay(address(1), "", 0);
    }

    modifier whenTimestampGEGatedUntil(uint256 _time) {
        // We compute a time and a block number to jump to. Let the block number be time / 12
        // We use gated_until + 12, to avoid an issue where the gated_until could be rounded down
        // and time be before gated_until
        uint256 time = bound(_time, treasury.GATED_UNTIL() + 12, type(uint256).max) / 12 * 12;
        vm.warp(time);

        uint256 blockNumber = time / 12;
        vm.roll(blockNumber);

        _;
    }

    function test_WhenBlocknumberLEBlockOfLastMarkNext(uint256 _time, uint256 _seed)
        external
        whenCallerEQGovernance
        whenTimestampGEGatedUntil(_time)
    {
        // it reverts {GateIsClosed}

        // If the has just been a mark in the same block, we are not allowing it.
        governance.setProposalCount(1);
        governance.setProposalState(0, _getDeadState(_seed));

        treasury.markNext();

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(IProtocolTreasury.GateIsClosed.selector, "markNext called this block"));
        treasury.relay(address(1), "", 0);
    }

    modifier whenBlocknumberGTBlockOfLastMarkNext(uint256 _seed) {
        // Add a dead proposal state and mark next to update the last marked time to be in the past (but non zero)
        governance.setProposalCount(1);
        governance.setProposalState(0, _getDeadState(_seed));

        treasury.markNext();

        vm.roll(block.number + 1);

        _;
    }

    function test_GivenOldestUnmarkedCreationLEActivationTime(
        uint256 _time,
        uint256 _seed,
        uint256 _proposalCreationTime
    ) external whenCallerEQGovernance whenTimestampGEGatedUntil(_time) whenBlocknumberGTBlockOfLastMarkNext(_seed) {
        // it reverts {GateIsClosed}

        // We need a proposal that was created before the treasury was activated
        // It does not actually matter if it is alive or dead if not marked. But alive cannot be marked.
        Proposal memory prop;
        prop.creation = Timestamp.wrap(bound(_proposalCreationTime, 0, treasury.getActivationTimestamp() - 1));

        // Add the proposal, it will be the next unmarked.
        uint256 proposalCount = governance.proposalCount();
        governance.setProposalCount(proposalCount + 1);
        governance.setProposal(proposalCount, prop, _getAliveState(_proposalCreationTime));

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(IProtocolTreasury.GateIsClosed.selector, "not activated yet"));
        treasury.relay(address(1), "", 0);
    }

    modifier givenOldestUnmarkedCreationGTActivationTime(uint256 _proposalCreationTime) {
        _;
    }

    function test_WhenValueGTBalance(uint256 _time, uint256 _seed, uint256 _proposalCreationTime, uint256 _payment)
        external
        whenCallerEQGovernance
        whenTimestampGEGatedUntil(_time)
        whenBlocknumberGTBlockOfLastMarkNext(_seed)
        givenOldestUnmarkedCreationGTActivationTime(_proposalCreationTime)
    {
        // it reverts

        uint256 payment = bound(_payment, 1, type(uint128).max);

        // Progress time to ensure that the insiders may act.
        uint256 ts = Math.max(block.timestamp, treasury.getActivationTimestamp() + 1);
        vm.warp(bound(_time, ts, type(uint256).max));

        // We need a new proposal that was started AFTER the insider can act time.
        // It does not actually matter if it is alive or dead if not marked.
        Proposal memory prop;
        prop.creation = Timestamp.wrap(bound(_proposalCreationTime, treasury.getActivationTimestamp() + 1, block.timestamp));

        uint256 proposalCount = governance.proposalCount();
        governance.setProposalCount(proposalCount + 1);
        governance.setProposal(proposalCount, prop, _getAliveState(_proposalCreationTime));

        string memory message = "We do be yeeting";

        assertEq(address(treasury).balance, 0);
        assertEq(yeeter.paidMessage(), "");

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientBalance.selector, 0, payment));
        treasury.relay(address(yeeter), abi.encodeWithSelector(Yeeter.payToYeet.selector, message), payment);
    }

    function test_WhenValueLEBalance(uint256 _time, uint256 _seed, uint256 _proposalCreationTime, uint256 _payment)
        external
        whenCallerEQGovernance
        whenTimestampGEGatedUntil(_time)
        whenBlocknumberGTBlockOfLastMarkNext(_seed)
        givenOldestUnmarkedCreationGTActivationTime(_proposalCreationTime)
    {
        // it transfers value to target
        // it executes the caller

        // For good measure. We will be testing:
        // 1. setMessage (external)
        // 2. payToYeet (external payable)
        // 3. claimYeetMoney (external that sends money to caller)
        // 4. pay EOA (send funds to an EOA, e.g., not contract)
        //
        // While we perform them individually, it would be the same as if we had them in a payload in governance.
        // They are called one after another without time or anything passing.
        uint256 payment = bound(_payment, 4, type(uint128).max);

        // Progress time to ensure that the insiders may act.
        uint256 ts = Math.max(block.timestamp, treasury.getActivationTimestamp() + 1);
        vm.warp(bound(_time, ts, type(uint256).max));

        // We need a new proposal that was started AFTER the insider can act time.
        // It does not actually matter if it is alive or dead if not marked.
        Proposal memory prop;
        prop.creation = Timestamp.wrap(bound(_proposalCreationTime, treasury.getActivationTimestamp() + 1, block.timestamp));

        uint256 proposalCount = governance.proposalCount();
        governance.setProposalCount(proposalCount + 1);
        governance.setProposal(proposalCount, prop, _getAliveState(_proposalCreationTime));

        string memory message = "We do be yeeting";

        // 1. setMessage
        assertEq(yeeter.freeMessage(), "");
        vm.prank(caller);
        treasury.relay(address(yeeter), abi.encodeWithSelector(Yeeter.setMessage.selector, message), 0);
        assertEq(yeeter.freeMessage(), message);
        assertEq(address(yeeter).balance, 0);

        // 2. payToYeet
        vm.deal(address(treasury), payment);
        assertEq(address(yeeter).balance, 0);
        assertEq(yeeter.paidMessage(), "");

        vm.prank(caller);
        treasury.relay(address(yeeter), abi.encodeWithSelector(Yeeter.payToYeet.selector, message), payment);

        assertEq(yeeter.paidMessage(), message);
        assertEq(address(yeeter).balance, payment);
        assertEq(address(treasury).balance, 0);

        // 3. Claim yeet money
        uint256 expectedClaim = payment / 2;
        vm.prank(caller);
        treasury.relay(address(yeeter), abi.encodeWithSelector(Yeeter.claimYeetMoney.selector), 0);

        assertEq(address(yeeter).balance, payment - expectedClaim);
        assertEq(address(treasury).balance, expectedClaim);

        // 4. Pay EOA
        address eoa = makeAddr("randomEOA");
        uint256 funding = address(treasury).balance / 2;
        assertGt(funding, 0);
        vm.prank(caller);
        treasury.relay(eoa, "", funding);

        assertEq(eoa.balance, funding);
    }
}
