pragma solidity ^0.8.0;

import {ILBPStrategyBasic} from "@launcher/interfaces/ILBPStrategyBasic.sol";
import {IPositionManager} from "@v4p/interfaces/IPositionManager.sol";
import {IPoolManager} from "@v4c/interfaces/IPoolManager.sol";

interface IVirtualLBPStrategyBasic is ILBPStrategyBasic {
    function approveMigration() external;

    function auction() external view returns (address);
    function positionManager() external view returns (IPositionManager);
    function positionRecipient() external view returns (address);
    function migrationBlock() external view returns (uint256);
    function sweepBlock() external view returns (uint256);
    function token() external view returns (address);
    function currency() external view returns (address);
    function poolLPFee() external view returns (uint24);
    function poolTickSpacing() external view returns (int24);
    function operator() external view returns (address);
    function poolManager() external view returns (IPoolManager);

    function UNDERLYING_TOKEN() external view returns (address);
    function GOVERNANCE() external view returns (address);
}