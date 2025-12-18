// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IRegistry} from "../Registry.sol";
import {NCATP} from "../atps/noclaim/NCATP.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

library NCATPFactory {
    /**
     * @notice Deploy the NCATP implementation
     * @param _registry The registry
     * @param _token The token
     * @return The NCATP implementation
     */
    function deployImplementation(IRegistry _registry, IERC20 _token) external returns (NCATP) {
        return new NCATP(_registry, _token);
    }
}
