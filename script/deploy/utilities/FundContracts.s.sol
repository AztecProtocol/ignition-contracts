// Script to fund the deployed contracts with the necessary funds
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {VirtualAztecToken} from "src/uniswap-periphery/VirtualAztecToken.sol";
import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";

import {GenesisSaleConfiguration, SaleConfiguration, ConfigurationVariant} from "../sale/GenesisSaleConfiguration.sol";
import {AuctionConfiguration} from "../twap/AuctionConfiguration.sol";

interface IERC20Mintable {
    function mint(address _to, uint256 _amount) external;
}

contract FundContracts is Script {
    struct DeployedContracts {
        address stakingAssetAddress;
        address virtualAztecToken;
        address auction;
        address tokenLauncher;
        address genesisSequencerSale;
        address fundsRecipient;
    }

    function getDeployedContracts() public view returns (DeployedContracts memory deployedContracts) {
        deployedContracts.stakingAssetAddress = vm.envAddress("STAKING_ASSET_ADDRESS");
        deployedContracts.virtualAztecToken = vm.envAddress("VIRTUAL_AZTEC_TOKEN_ADDRESS");
        deployedContracts.auction = vm.envAddress("AUCTION_ADDRESS");
        deployedContracts.tokenLauncher = vm.envAddress("TOKEN_LAUNCHER_ADDRESS");
        deployedContracts.genesisSequencerSale = vm.envAddress("GENESIS_SEQUENCER_SALE_ADDRESS");
    }

    function run() public {
        // Get the deployed contracts
        DeployedContracts memory deployedContracts = getDeployedContracts();

        SaleConfiguration memory saleConfiguration =
            new GenesisSaleConfiguration(ConfigurationVariant.DRESS).getSaleConfiguration();
        uint256 auctionTotalSupply =
            new AuctionConfiguration(ConfigurationVariant.DRESS).getTokenSplits().auctionTotalSupply;

        // Mint tokens to the genesis sequncer sale contract
        vm.broadcast();
        IERC20Mintable(deployedContracts.stakingAssetAddress).mint(
            address(deployedContracts.genesisSequencerSale), saleConfiguration.supply
        );

        // Mint the tokens for the auction contract
        // Mint tokens underlying tokens to the msg.sender
        vm.broadcast();
        IERC20Mintable(deployedContracts.stakingAssetAddress).mint(msg.sender, auctionTotalSupply);

        vm.broadcast();
        IERC20(deployedContracts.stakingAssetAddress).approve(
            address(deployedContracts.virtualAztecToken), auctionTotalSupply
        );

        vm.broadcast();
        IERC20Mintable(deployedContracts.virtualAztecToken).mint(
            address(deployedContracts.fundsRecipient), auctionTotalSupply
        );
    }
}
