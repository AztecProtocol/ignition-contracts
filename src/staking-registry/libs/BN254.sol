// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

library BN254Lib {
    /**
     * @title G1Point
     * @notice A point on the BN254 G1 curve
     */
    struct G1Point {
        /// @notice The x coordinate
        uint256 x;
        /// @notice The y coordinate
        uint256 y;
    }

    /**
     * @title G2Point
     * @notice A point on the BN254 paired G2 curve
     */
    struct G2Point {
        /// @notice The x coordinate - first part
        uint256 x0;
        /// @notice The x coordinate - second part
        uint256 x1;
        /// @notice The y coordinate - first part
        uint256 y0;
        /// @notice The y coordinate - second part
        uint256 y1;
    }

    struct KeyStore {
        /// @notice The address of the attester
        address attester;
        /// @notice - The BLS public key - BN254 G1
        G1Point publicKeyG1;
        /// @notice - The BLS public key - BN254 G2
        G2Point publicKeyG2;
        /// @notice - The BLS signature - required to prevent rogue key attacks
        G1Point signature;
    }
}
