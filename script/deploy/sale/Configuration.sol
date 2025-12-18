// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

struct ZkPassportConfiguration {
    address verifierAddress;
    string domain;
    string scope;
}

struct PredicateConfiguration {
    address managerAddress;
    string addressScreeningPolicyId;
    string kycPolicyId;
}

struct AtpConfiguration {
    uint256 unlockCliffDuration;
    uint256 unlockLockDuration;
    uint256 executionAllowedAt;
    uint256 ncatpWithdrawalTimestamp;
}

struct SaleConfiguration {
    uint256 pricePerLot;
    uint256 supply;
    uint96 saleStartTime;
    uint96 saleEndTime;
}

interface ISaleConfiguration {
    function getSaleConfiguration() external view returns (SaleConfiguration memory);
    function getAtpConfiguration() external view returns (AtpConfiguration memory);
    function getZkPassportConfiguration() external view returns (ZkPassportConfiguration memory);
    function getPredicateConfiguration() external view returns (PredicateConfiguration memory);
    function getPullSplitFactoryAddress() external view returns (address);
}
