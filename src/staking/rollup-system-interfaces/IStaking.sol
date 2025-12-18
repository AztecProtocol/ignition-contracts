// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

/**
 * @title Staking Minimal Interface
 * @author Aztec-Labs
 * @notice A minimal interface for the Staking contract
 *
 * @dev includes only the function that are interacted with from the staker
 */
interface IStaking {
    // TODO: make this line up with the real staking contract
    event Staked(address indexed attester, uint256 amount);

    function deposit(
        address _attester,
        address _withdrawer,
        BN254Lib.G1Point memory _publicKeyG1,
        BN254Lib.G2Point memory _publicKeyG2,
        BN254Lib.G1Point memory _signature,
        bool _moveWithRollup
    ) external;
    function initiateWithdraw(address _attester, address _recipient) external;
    function finaliseWithdraw(address _attester) external;
    function claimSequencerRewards(address _sequencer) external;

    function getActivationThreshold() external view returns (uint256);
    function getGSE() external view returns (address);
}
