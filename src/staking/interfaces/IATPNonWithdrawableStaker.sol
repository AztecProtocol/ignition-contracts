// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {BN254Lib} from "src/staking-registry/libs/BN254.sol";
import {IGovernanceATP} from "./IGovernanceATP.sol";

interface IATPNonWithdrawableStaker is IGovernanceATP {
    function stake(
        uint256 _version,
        address _attester,
        BN254Lib.G1Point memory _publicKeyG1,
        BN254Lib.G2Point memory _publicKeyG2,
        BN254Lib.G1Point memory _signature,
        bool _moveWithLatestRollup
    ) external;
    function stakeWithProvider(
        uint256 _version,
        uint256 _providerIdentifier,
        uint16 _expectedProviderTakeRate,
        address _userRewardsRecipient,
        bool _moveWithLatestRollup
    ) external;
    function moveFundsBackToATP() external;
    function claimRewards(uint256 _version) external;
    function delegate(uint256 _version, address _attester, address _delegatee) external;
}
