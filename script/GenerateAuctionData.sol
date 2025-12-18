// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IContinuousClearingAuction, AuctionParameters} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";
import {Tick} from "@twap-auction/interfaces/ITickStorage.sol";
import {FixedPoint96} from "@twap-auction/libraries/FixedPoint96.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

// Internal
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
import {AuctionConfiguration, TwapConfig} from "./deploy/twap/AuctionConfiguration.sol";
import {ConfigurationVariant, SharedConfigGetter} from "./deploy/SharedConfig.sol";

contract GenerateAuctionData is Script {
    using FixedPointMathLib for uint128;

    IContinuousClearingAuction auction = IContinuousClearingAuction(vm.envAddress("TWAP_AUCTION_ADDRESS"));

    event log_named_decimal_uint(string key, uint256 val, uint256 decimals);

    address constant ANVIL_4_ADDRESS = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65; // Anvil4 is in contributor merkle tree
    uint256 constant ANVIL_4_PRIVATE_KEY = 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a;

    function run() external {
        vm.roll(auction.startBlock() + 1);
        console2.log("Generate ContinuousClearingAuction Data. Current block: ", block.number);
        generateBids(10);
    }

    function generateBids(uint8 numBids) public {
        TwapConfig memory twapConfig =
            new AuctionConfiguration(new SharedConfigGetter().getConfigurationVariant()).getTwapConfig();

        uint256 floorPrice = twapConfig.floorPrice;
        uint256 maxPrice = floorPrice; // default to the floor price, doubled for every bid below
        uint256 lastTickPrice = floorPrice;

        address soulbound = vm.envAddress("SOULBOUND_ADDRESS");

        // The sender must have a contributor token in order to submit a bid
        uint256 balance = IIgnitionParticipantSoulbound(soulbound).balanceOf(
            ANVIL_4_ADDRESS, uint256(IIgnitionParticipantSoulbound.TokenId.CONTRIBUTOR)
        );
        if (balance == 0) {
            vm.broadcast();
            IIgnitionParticipantSoulbound(soulbound).adminMint(
                ANVIL_4_ADDRESS,
                IIgnitionParticipantSoulbound.TokenId.CONTRIBUTOR,
                /*gridTileId*/
                1
            );
        }

        for (uint256 i = 0; i < numBids; i++) {
            maxPrice += floorPrice; // Increase the maxPrice by floorPrice on every iteration
            maxPrice = (maxPrice / twapConfig.tickSpacing) * twapConfig.tickSpacing;

            // purchase 50 tokens at the maxPrice
            uint128 amount = getAmountRequiredToPurchaseTokens(200 ether, maxPrice);

            console2.log("\n========================================");
            console2.log("Bid Number: ", i + 1);
            logQ96AmountWithDecimal("Token Price (ETH)", maxPrice);
            logAmountWithDecimal("Amount Paid (ETH)", amount);
            logAmountWithDecimal("Estimated tokens: ", uint128((amount * 1e8) / ((maxPrice * 1e8) >> 96)));
            console2.log("\n========================================\n");

            // Impersonate as Anvil default account #1 - which has 10000 ETH
            vm.broadcast(ANVIL_4_PRIVATE_KEY);
            auction.submitBid{value: amount, gas: 1000000}(
                maxPrice, // maxPrice
                amount, // amount
                ANVIL_4_ADDRESS, // owner
                lastTickPrice, // previousPrice
                "" // hookData
            );

            // Advance block
            console2.log("Advancing block to: ", block.number + 1);
            vm.roll(block.number + 1);

            // set the new price as lastTickPrice
            lastTickPrice = maxPrice;
        }
    }

    function getAmountRequiredToPurchaseTokens(uint128 numTokens, uint256 maxPrice) internal pure returns (uint128) {
        return uint128(numTokens.fullMulDivUp(maxPrice, FixedPoint96.Q96));
    }

    function logAmountWithDecimal(string memory key, uint128 amount) internal {
        emit log_named_decimal_uint(key, amount, 18);
    }

    function logQ96AmountWithDecimal(string memory key, uint256 amount) internal {
        emit log_named_decimal_uint(key, ((amount * 1e18) >> FixedPoint96.RESOLUTION), 18);
    }
}
