// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Aztec Labs.
pragma solidity >=0.8.27;

import {Ownable} from "@oz/access/Ownable.sol";
import {Ownable2Step} from "@oz/access/Ownable2Step.sol";
import {IMintableERC20} from "@aztec/shared/interfaces/IMintableERC20.sol";
import {CoinIssuer} from "@aztec/governance/CoinIssuer.sol";
import {IPermit2} from "@launcher/../lib/permit2/src/interfaces/IPermit2.sol";
import {ILiquidityLauncher} from "@launcher/interfaces/ILiquidityLauncher.sol";
import {Distribution} from "@launcher/types/Distribution.sol";
import {IVirtualLBPStrategyBasic} from "src/uniswap-periphery/IVirtualLBPStrategyBasic.sol";

struct FoundationAztecConfig {
    address token;
    address governance;
    address rewardDistributor;
    address flushRewarder;
    address coinIssuer;
    address protocolTreasury;
    uint256 tokensToRewardDistributor;
    uint256 tokensToFlushRewarder;
}

struct FoundationGenesisSaleConfig {
    address genesisSequencerSale;
    uint256 tokensToGenesisSequencerSale;
}

struct FoundationTwapConfig {
    address virtualToken;
    uint128 tokensToVirtualToken;
    address permit2;
    address tokenLauncher;
    Distribution distributionParams;
    bytes32 generatedSalt;
    address auction;
}

struct TwapGovPayloadConfig {
    address atpRegistry;
    address dateGatedRelayerShort;
}

struct ProtocolTreasuryConfig {
    uint256 tokensForTreasury;
}

struct FoundationFundingConfig {
    uint256 mintToFunder;
}

struct FoundationPayloadConfig {
    address funder;
    FoundationFundingConfig foundationFunding;
    FoundationAztecConfig aztec;
    FoundationGenesisSaleConfig genesisSale;
    FoundationTwapConfig twap;
    TwapGovPayloadConfig govPayload;
    ProtocolTreasuryConfig protocolTreasuryConfig;
}

contract FoundationPayload is Ownable {
    FoundationPayloadConfig public $config;
    bool public isSet = false;

    IVirtualLBPStrategyBasic public virtualLBP;

    constructor(address __owner) Ownable(__owner) {}

    function setConfig(FoundationPayloadConfig memory _config) public onlyOwner {
        require(!isSet, "Config already set");
        $config = _config;
        isSet = true;
    }

    /**
     * @notice
     * @dev     The token must be pending owned by this contract when called
     */
    function run() external onlyOwner {
        _acceptOwnerships();
        _fundRewarders();
        _fundFoundation();
        _fundTreasury();
        _fundGenesisSale();

        _twapAuction();

        _handoverOwnerships();

        // Only allow execution once. Renounce.
        _transferOwnership(address(0));
    }

    function getApprovalAmount() external view returns (uint256) {
        return $config.genesisSale.tokensToGenesisSequencerSale + $config.twap.tokensToVirtualToken
            + $config.protocolTreasuryConfig.tokensForTreasury;
    }

    function getConfig() external view returns (FoundationPayloadConfig memory) {
        return $config;
    }

    function _acceptOwnerships() internal {
        IMintableERC20 token = IMintableERC20($config.aztec.token);
        Ownable2Step(address(token)).acceptOwnership();
    }

    function _fundFoundation() internal {
        IMintableERC20 token = IMintableERC20($config.aztec.token);
        address account = $config.funder;
        uint256 amount = $config.foundationFunding.mintToFunder;

        uint256 before = token.balanceOf(account);

        token.mint(account, amount);

        ////////////////////////////////
        ////////// Assertions //////////
        ////////////////////////////////

        require(token.balanceOf(account) == before + amount);
    }

    function _fundRewarders() internal {
        IMintableERC20 token = IMintableERC20($config.aztec.token);
        uint256 supplyBefore = token.totalSupply();
        uint256 rewardDistributorBalanceBefore = token.balanceOf($config.aztec.rewardDistributor);
        uint256 flushRewarderBalanceBefore = token.balanceOf($config.aztec.flushRewarder);

        uint256 rewardDistributorAmount = $config.aztec.tokensToRewardDistributor;
        uint256 flushRewarderAmount = $config.aztec.tokensToFlushRewarder;

        token.mint($config.aztec.rewardDistributor, rewardDistributorAmount);
        token.mint($config.aztec.flushRewarder, flushRewarderAmount);

        ////////////////////////////////
        ////////// Assertions //////////
        ////////////////////////////////

        require(
            token.balanceOf($config.aztec.rewardDistributor) == rewardDistributorBalanceBefore + rewardDistributorAmount,
            "Reward distributor balance mismatch"
        );
        require(
            token.balanceOf($config.aztec.flushRewarder) == flushRewarderBalanceBefore + flushRewarderAmount,
            "Flush rewarder balance mismatch"
        );
        require(
            token.totalSupply() == supplyBefore + rewardDistributorAmount + flushRewarderAmount, "Token supply mismatch"
        );
    }

    function _fundTreasury() internal {
        IMintableERC20 token = IMintableERC20($config.aztec.token);
        address treasury = $config.aztec.protocolTreasury;
        uint256 amount = $config.protocolTreasuryConfig.tokensForTreasury;

        uint256 balanceBefore = token.balanceOf(treasury);

        token.transferFrom($config.funder, treasury, amount);

        ////////////////////////////////
        ////////// Assertions //////////
        ////////////////////////////////

        require(token.balanceOf(treasury) == balanceBefore + amount, "invalid treasury funding");
    }

    function _fundGenesisSale() internal {
        IMintableERC20 token = IMintableERC20($config.aztec.token);
        address sale = $config.genesisSale.genesisSequencerSale;
        uint256 amount = $config.genesisSale.tokensToGenesisSequencerSale;
        uint256 genesisSequencerSaleBalanceBefore = token.balanceOf(sale);

        token.transferFrom($config.funder, sale, amount);

        ////////////////////////////////
        ////////// Assertions //////////
        ////////////////////////////////

        require(
            token.balanceOf(sale) == genesisSequencerSaleBalanceBefore + amount,
            "Genesis sequencer sale balance mismatch"
        );
    }

    function _twapAuction() internal {
        IMintableERC20 token = IMintableERC20($config.aztec.token);
        uint128 tokensToVirtualToken = uint128($config.twap.tokensToVirtualToken);
        IMintableERC20 vToken = IMintableERC20($config.twap.virtualToken);

        require(Ownable(address(vToken)).owner() == address(this), "Virtual token not owned by this contract");

        token.transferFrom($config.funder, address(this), tokensToVirtualToken);
        token.approve(address(vToken), tokensToVirtualToken);
        vToken.mint(address(this), tokensToVirtualToken);
        vToken.approve($config.twap.permit2, tokensToVirtualToken);
        IPermit2($config.twap.permit2).approve(
            address(vToken), $config.twap.tokenLauncher, tokensToVirtualToken, type(uint48).max
        );
        virtualLBP = IVirtualLBPStrategyBasic(
            payable(
                address(
                    ILiquidityLauncher($config.twap.tokenLauncher).distributeToken(
                        address(vToken), $config.twap.distributionParams, true, $config.twap.generatedSalt
                    )
                )
            )
        );

        address auction = address(virtualLBP.auction());
        require(auction == $config.twap.auction, "ContinuousClearingAuction address mismatch");
        require(auction.code.length > 0, "ContinuousClearingAuction address has no code");
        // @todo feed it the auction address and ensure match
    }

    function _handoverOwnerships() internal {
        Ownable($config.aztec.token).transferOwnership($config.aztec.coinIssuer);
        CoinIssuer($config.aztec.coinIssuer).acceptTokenOwnership();
        Ownable($config.aztec.coinIssuer).transferOwnership($config.aztec.protocolTreasury);

        Ownable2Step($config.govPayload.atpRegistry).acceptOwnership();
        Ownable2Step($config.govPayload.atpRegistry).transferOwnership($config.govPayload.dateGatedRelayerShort);

        ////////////////////////////////
        ////////// Assertions //////////
        ////////////////////////////////

        require(Ownable($config.aztec.token).owner() == $config.aztec.coinIssuer, "Token owner mismatch");
        require(
            Ownable($config.aztec.coinIssuer).owner() == $config.aztec.protocolTreasury, "Coin issuer owner mismatch"
        );
        require(
            Ownable($config.aztec.protocolTreasury).owner() == $config.aztec.governance,
            "Protocol Treasury owner mismatch"
        );
        require(
            Ownable2Step($config.govPayload.atpRegistry).pendingOwner() == $config.govPayload.dateGatedRelayerShort,
            "ATP registry pending owner mismatch"
        );
    }
}
