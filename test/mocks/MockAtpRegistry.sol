// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

contract MockATPRegistry {
    uint256 internal executeAllowedAt;

    constructor(uint256 _executeAllowedAt) {
        executeAllowedAt = _executeAllowedAt;
    }

    function getExecuteAllowedAt() external view returns (uint256) {
        return executeAllowedAt;
    }
}
