// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IVirtualLBPStrategyBasic} from "src/uniswap-periphery/IVirtualLBPStrategyBasic.sol";

import {PoolKey} from "@v4c/types/PoolKey.sol";
import {Currency} from "@v4c/types/Currency.sol";
import {IHooks} from "@v4c/interfaces/IHooks.sol";
import {IV4Router} from "@v4p/interfaces/IV4Router.sol";
import {Actions} from "@v4p/libraries/Actions.sol";

import {Base} from "./Base.sol";

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}

contract UniswapTradeTest is Base {
    function test_uniswapTrade() public {
        address trader = makeAddr("trader");

        IVirtualLBPStrategyBasic strategy = tgePayload.VIRTUAL_LBP_STRATEGY();

        // Build the pool key (ETH is address(0), token is AZTEC_TOKEN)
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(AZTEC_TOKEN)),
            fee: strategy.poolLPFee(),
            tickSpacing: strategy.poolTickSpacing(),
            hooks: IHooks(address(strategy))
        });

        // 1. Show that trading is NOT possible before the proposal
        // The MigrationNotApproved error is wrapped by the PoolManager
        vm.expectRevert();
        _swap(trader, key, 1 ether);

        // 2. Execute the proposal (which calls approveMigration)
        proposeAndExecuteProposal();

        // 3. Show that trading IS possible after the proposal
        uint256 tokenBalanceBefore = AZTEC_TOKEN.balanceOf(trader);

        _swap(trader, key, 1 ether);

        uint256 tokenBalanceAfter = AZTEC_TOKEN.balanceOf(trader);

        assertGt(tokenBalanceAfter, tokenBalanceBefore, "Should have received tokens from swap");
    }

    function _swap(address _caller, PoolKey memory key, uint256 amountIn) internal {
        // UniversalRouter on mainnet
        IUniversalRouter router = IUniversalRouter(0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af);

        // zeroForOne = true means swapping currency0 for currency1
        // We're swapping ETH (currency0) for AZTEC tokens (currency1)
        bool zeroForOne = true;

        Currency currencyIn = key.currency0;
        Currency currencyOut = key.currency1;

        // Encode the Universal Router command (V4_SWAP = 0x10)
        bytes memory commands = abi.encodePacked(uint8(0x10));

        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key, zeroForOne: zeroForOne, amountIn: uint128(amountIn), amountOutMinimum: 0, hookData: ""
            })
        );
        params[1] = abi.encode(currencyIn, amountIn);
        params[2] = abi.encode(currencyOut, uint256(0));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);

        vm.deal(_caller, amountIn + 1 ether);
        vm.prank(_caller);
        router.execute{value: amountIn}(commands, inputs, block.timestamp + 60);
    }
}
