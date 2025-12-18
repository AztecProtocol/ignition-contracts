// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

interface IPayload {
    struct Action {
        address target;
        bytes data;
    }

    /**
     * @notice  A URI that can be used to refer to where a non-coder human readable description
     *          of the payload can be found.
     *
     * @dev     Not used in the contracts, so could be any string really
     *
     * @return - Ideally a useful URI for the payload description
     */
    function getURI() external view returns (string memory);

    function getActions() external view returns (Action[] memory);
}

interface IGovernance {
    event Deposit(address indexed depositor, address indexed onBehalfOf, uint256 amount);
    event WithdrawInitiated(uint256 indexed withdrawalId, address indexed recipient, uint256 amount);
    event WithdrawFinalized(uint256 indexed withdrawalId);
    event Proposed(uint256 indexed proposalId, address indexed proposal);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 amount);

    function deposit(address _onBehalfOf, uint256 _amount) external;
    function initiateWithdraw(address _to, uint256 _amount) external returns (uint256);
    function finalizeWithdraw(uint256 _withdrawalId) external;
    function proposeWithLock(IPayload _proposal, address _to) external returns (uint256);
    function vote(uint256 _proposalId, uint256 _amount, bool _support) external;
}
