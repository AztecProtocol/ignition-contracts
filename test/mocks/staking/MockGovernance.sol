// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IGovernance, IPayload} from "src/staking/rollup-system-interfaces/IGovernance.sol";

import {IERC20} from "@oz/token/ERC20/IERC20.sol";

contract MockGovernance is IGovernance {
    struct Withdrawal {
        uint256 amount;
        uint256 unlocksAt;
        address recipient;
        bool claimed;
    }

    struct Proposal {
        IPayload payload;
        uint256 yays;
        uint256 nays;
    }

    IERC20 public asset;

    mapping(address => uint256) public users;
    uint256 public total;

    mapping(uint256 => Withdrawal) public withdrawals;
    mapping(uint256 => Proposal) public proposals;

    uint256 public withdrawalId;
    uint256 public proposalId;

    // arbitrary for testing
    uint256 public LOCK_AMOUNT = 100;

    constructor(address _asset) {
        asset = IERC20(_asset);
    }

    function deposit(address _beneficiary, uint256 _amount) external {
        asset.transferFrom(msg.sender, address(this), _amount);

        users[_beneficiary] += _amount;
        total += _amount;

        emit Deposit(msg.sender, _beneficiary, _amount);
    }

    function initiateWithdraw(address _to, uint256 _amount) external returns (uint256) {
        return _initiateWithdraw(msg.sender, _to, _amount, 100);
    }

    function finalizeWithdraw(uint256 _withdrawalId) external {
        Withdrawal storage withdrawal = withdrawals[_withdrawalId];

        require(withdrawal.recipient != address(0), "Withdrawal not found");
        require(!withdrawal.claimed, "Withdrawal already claimed");
        require(block.timestamp >= withdrawal.unlocksAt, "Withdrawal not unlocked");
        withdrawal.claimed = true;

        emit WithdrawFinalized(_withdrawalId);

        asset.transfer(withdrawal.recipient, withdrawal.amount);
    }

    function proposeWithLock(IPayload _proposal, address _to) external returns (uint256) {
        _initiateWithdraw(msg.sender, _to, LOCK_AMOUNT, 1000);
        return _propose(_proposal, address(this));
    }

    function vote(uint256 _proposalId, uint256 _amount, bool _support) external {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.payload != IPayload(address(0)), "Proposal not found");
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= users[msg.sender], "Insufficient power");
        require(_support == true || _support == false, "Invalid support");

        if (_support) {
            proposal.yays += _amount;
        } else {
            proposal.nays += _amount;
        }

        emit VoteCast(_proposalId, msg.sender, _support, _amount);
    }

    function _initiateWithdraw(address _from, address _to, uint256 _amount, uint256 _delay) internal returns (uint256) {
        users[_from] -= _amount;
        total -= _amount;

        uint256 withdrawalId = withdrawalId++;
        withdrawals[withdrawalId] =
            Withdrawal({amount: _amount, unlocksAt: block.timestamp + _delay, recipient: _to, claimed: false});

        emit WithdrawInitiated(withdrawalId, _to, _amount);

        return withdrawalId;
    }

    // mock has no checks
    function proposeMock(IPayload _proposal) external returns (uint256) {
        return _propose(_proposal, msg.sender);
    }

    function _propose(IPayload _proposal, address _proposer) internal returns (uint256) {
        uint256 proposalId = proposalId++;
        proposals[proposalId] = Proposal({payload: _proposal, yays: 0, nays: 0});

        emit Proposed(proposalId, address(_proposal));

        return proposalId;
    }
}
