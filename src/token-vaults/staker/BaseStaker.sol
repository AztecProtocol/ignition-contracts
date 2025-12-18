// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {ERC1967Utils} from "@oz/proxy/ERC1967/ERC1967Utils.sol";
import {UUPSUpgradeable} from "@oz/proxy/utils/UUPSUpgradeable.sol";
import {IATPCore} from "../atps/base/IATP.sol";

interface IBaseStaker {
    function initialize(address _atp) external;

    function getATP() external view returns (address);
    function getOperator() external view returns (address);
    function getImplementation() external view returns (address);
}

contract BaseStaker is IBaseStaker, UUPSUpgradeable {
    address internal atp;

    error AlreadyInitialized();
    error ZeroATP();
    error NotATP(address caller, address atp);
    error NotOperator(address caller, address operator);

    modifier onlyOperator() {
        address operator = getOperator();
        require(msg.sender == operator, NotOperator(msg.sender, operator));
        _;
    }

    modifier onlyATP() {
        require(msg.sender == address(atp), NotATP(msg.sender, address(atp)));
        _;
    }

    constructor() {
        atp = address(0xdead);
    }

    function initialize(address _atp) external virtual override(IBaseStaker) {
        require(address(_atp) != address(0), ZeroATP());
        require(address(atp) == address(0), AlreadyInitialized());

        atp = _atp;
    }

    function getImplementation() external view virtual override(IBaseStaker) returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function getATP() public view virtual override(IBaseStaker) returns (address) {
        return atp;
    }

    function getOperator() public view virtual override(IBaseStaker) returns (address) {
        return IATPCore(atp).getOperator();
    }

    function _authorizeUpgrade(address _newImplementation) internal virtual override(UUPSUpgradeable) onlyATP {}
}
