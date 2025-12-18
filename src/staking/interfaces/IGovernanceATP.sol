// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IPayload} from "src/staking/rollup-system-interfaces/IGovernance.sol";

interface IGovernanceATP {
    function depositIntoGovernance(uint256 _amount) external;
    function voteInGovernance(uint256 _proposalId, uint256 _amount, bool _support) external;
    function initiateWithdrawFromGovernance(uint256 _amount) external returns (uint256);
    function proposeWithLock(IPayload _proposal) external returns (uint256);
}
