// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IGSE} from "src/staking/rollup-system-interfaces/IGSE.sol";
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

/**
 * @title MockGSE
 * @author Aztec-Labs
 * @notice Mock GSE contract for testing
 */
contract MockGSE is IGSE {
    error NotTheWithdrawer();
    error NotTheAttester();
    error NotAnInstance();

    mapping(address attester => address delegatee) public delegatees;
    mapping(address delegatee => uint256 power) public powers;
    mapping(address rollup => bool isInstance) public isInstance;

    mapping(address attester => address withdrawer) public withdrawers;
    mapping(address attester => uint256 stake) public staked;

    function addRollup(address _rollup) external {
        isInstance[_rollup] = true;
    }

    function deposit(
        address _attester,
        address _withdrawer,
        BN254Lib.G1Point memory _publicKeyG1,
        BN254Lib.G2Point memory _publicKeyG2,
        BN254Lib.G1Point memory _signature,
        bool _moveWithRollup
    ) external {
        // Call comes from a rollup instance
        require(isInstance[msg.sender], "Instance not found");
        withdrawers[_attester] = _withdrawer;
        staked[_attester] += ACTIVATION_THRESHOLD();
    }

    function delegate(address _instance, address _attester, address _delegatee) external {
        require(isInstance[_instance], NotAnInstance());
        require(withdrawers[_attester] == msg.sender, NotTheWithdrawer());

        // Remove the current delegatee's power
        address currentDelegatee = delegatees[_attester];
        if (currentDelegatee != address(0)) {
            powers[currentDelegatee] -= staked[_attester];
        }

        // Add the new delegatee's power
        delegatees[_attester] = _delegatee;
        powers[_delegatee] += staked[_attester];
    }

    function ACTIVATION_THRESHOLD() public view returns (uint256) {
        return 300_000 ether;
    }
}
