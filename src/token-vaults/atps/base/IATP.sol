// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {Lock} from "../../libraries/LockLib.sol";
import {IRegistry, StakerVersion} from "../../Registry.sol";
import {IBaseStaker} from "./../../staker/BaseStaker.sol";

enum ATPType {
    Linear,
    Milestone,
    NonClaim
}

interface IATPCore {
    event StakerInitialized(IBaseStaker staker);
    event StakerUpgraded(StakerVersion version);
    event StakerOperatorUpdated(address operator);
    event Claimed(uint256 amount);
    event ApprovedStaker(uint256 allowance);
    event Rescued(address asset, address to, uint256 amount);
    event Revoked(uint256 amount);

    error AlreadyInitialized();
    error InvalidBeneficiary(address beneficiary);
    error NotBeneficiary(address caller, address beneficiary);
    error LockHasEnded();
    error InvalidTokenAddress(address token);
    error InvalidRegistry(address registry);
    error AllocationMustBeGreaterThanZero();
    error InvalidAsset(address asset);
    error ExecutionNotAllowedYet(uint256 timestamp, uint256 executeAllowedAt);
    error NotRevokable();
    error NotRevoker(address caller, address revoker);
    error NoClaimable();
    error LockDurationMustBeGTZero(string variant);
    error InvalidUpgrade();

    function upgradeStaker(StakerVersion _version) external;
    function approveStaker(uint256 _allowance) external;
    function updateStakerOperator(address _operator) external;
    function claim() external returns (uint256);
    function rescueFunds(address _asset, address _to) external;
    function revoke() external returns (uint256);
    function getClaimable() external view returns (uint256);
    function getGlobalLock() external view returns (Lock memory);
    function getBeneficiary() external view returns (address);
    function getOperator() external view returns (address);
}

interface IATPPeriphery {
    function getToken() external view returns (IERC20);
    function getRegistry() external view returns (IRegistry);
    function getExecuteAllowedAt() external view returns (uint256);

    function getClaimed() external view returns (uint256);
    function getRevoker() external view returns (address);
    function getIsRevokable() external view returns (bool);
    function getAllocation() external view returns (uint256);

    function getType() external view returns (ATPType);
    function getStaker() external view returns (IBaseStaker);
}
