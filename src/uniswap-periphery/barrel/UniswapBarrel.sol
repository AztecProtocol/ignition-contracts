// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

import {ContinuousClearingAuction, AuctionParameters} from "@twap-auction/ContinuousClearingAuction.sol";
import {VirtualLBPStrategyBasic} from "@launcher/distributionContracts/VirtualLBPStrategyBasic.sol";
import {MigratorParameters} from "@launcher/types/MigratorParameters.sol";
import {IPositionManager} from "@v4p/interfaces/IPositionManager.sol";
import {IPoolManager} from "@v4c/interfaces/IPoolManager.sol";

// Useless barrel contract to ensure their builds end up in the out folder
contract UniswapBarrel {
    ContinuousClearingAuction public auction;
    VirtualLBPStrategyBasic public strategy;

    constructor() {
        auction = new ContinuousClearingAuction(address(0), 0, AuctionParameters({
            currency: address(0),
            tokensRecipient: address(0),
            fundsRecipient: address(0),
            startBlock: 0,
            endBlock: 0,
            claimBlock: 0,
            floorPrice: 0,
            tickSpacing: 0,
            validationHook: address(0),
            requiredCurrencyRaised: 0,
            auctionStepsData: bytes("")
        }));
        strategy = new VirtualLBPStrategyBasic(address(0), 0, MigratorParameters({
            migrationBlock: 0,
            currency: address(0),
            poolLPFee: 0,
            poolTickSpacing: 0,
            tokenSplitToAuction: 0,
            auctionFactory: address(0),
            positionRecipient: address(0),
            sweepBlock: 0,
            operator: address(0),
            createOneSidedTokenPosition: false,
            createOneSidedCurrencyPosition: false
        }), bytes(""), IPositionManager(address(0)), IPoolManager(address(0)), address(0));
    }
}