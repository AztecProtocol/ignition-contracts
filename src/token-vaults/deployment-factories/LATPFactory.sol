// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IRegistry} from "../Registry.sol";
import {LATP} from "../atps/linear/LATP.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

library LATPFactory {
    /**
     * @notice Deploy the LATP implementation
     * @param _registry The registry
     * @param _token The token
     * @return The LATP implementation
     */
    function deployImplementation(IRegistry _registry, IERC20 _token) external returns (LATP) {
        return new LATP(_registry, _token);
    }
}
