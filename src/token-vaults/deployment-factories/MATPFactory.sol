// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IRegistry} from "../Registry.sol";
import {MATP} from "../atps/milestone/MATP.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

library MATPFactory {
    /**
     * @notice Deploy the MATP implementation
     * @param _registry The registry
     * @param _token The token
     * @return The MATP implementation
     */
    function deployImplementation(IRegistry _registry, IERC20 _token) external returns (MATP) {
        return new MATP(_registry, _token);
    }
}
