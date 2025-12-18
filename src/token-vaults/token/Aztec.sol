// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Ownable2Step, Ownable} from "@oz/access/Ownable2Step.sol";
import {ERC20} from "@oz/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@oz/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20Mintable} from "./IERC20Mintable.sol";

contract Aztec is IERC20Mintable, ERC20, Ownable2Step, ERC20Permit {
    constructor(address _initialOwner) ERC20("AZTEC", "AZTEC") Ownable(_initialOwner) ERC20Permit("AZTEC") {}

    /**
     * @notice  Mint tokens
     *
     * @dev Only callable by the owner
     *
     * @param _to   The address to mint the tokens to
     * @param _amount   The amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external override(IERC20Mintable) onlyOwner {
        _mint(_to, _amount);
    }
}
