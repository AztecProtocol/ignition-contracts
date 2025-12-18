// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

// @todo: showcase parameters of deployed contracts also

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {Ownable2Step} from "@oz/access/Ownable2Step.sol";

contract OwnershipLogging is Test {
    mapping(address => string) internal labels;
    mapping(string => address) internal addresses;
    mapping(address => address) internal owners;
    mapping(address => address) internal pendingOwners;

    function log_ownerships() public {
        string memory chainId = vm.toString(block.chainid);
        // Always write to contracts/deployments/ (inside foundry project root)
        // The bootstrap script will copy this to the correct location
        string memory deploymentsDir = vm.envString("DEPLOYMENTS_DIR");
        if (!vm.exists(deploymentsDir)) {
            vm.createDir(deploymentsDir, true);
        }
        string memory inputPath = string.concat(deploymentsDir, "/collective-l1-deployment-", chainId, ".json");

        string memory json = vm.readFile(inputPath);

        emit log("################################################");
        emit log("Ownership of contracts");
        emit log_named_string("inputPath", inputPath);
        emit log("");

        emit log("Common addresses");
        emit log("============== Foundation Wallets =================");

        string[] memory foundationWalletsLabels = new string[](6);
        foundationWalletsLabels[0] = "deployerAddress";
        foundationWalletsLabels[1] = "tokenOwnerAddress";
        foundationWalletsLabels[2] = "genesisSaleOwnerAddress";
        foundationWalletsLabels[3] = "twapTokenRecipientAddress";
        foundationWalletsLabels[4] = "auctionOperatorAddress";
        foundationWalletsLabels[5] = "lowValueOwnerAddress";
        _log_section(json, foundationWalletsLabels);

        emit log("=========== Foundation Payload =============");

        _populate(json, "foundationPayloadAddress");
        _log_ownership("foundationPayloadAddress");

        emit log("");

        emit log("============== Aztec Contracts =================");

        string[] memory aztecLabels = new string[](11);
        aztecLabels[0] = "governanceAddress";
        aztecLabels[1] = "gseAddress";
        aztecLabels[2] = "registryAddress";
        aztecLabels[3] = "governanceProposerAddress";
        aztecLabels[4] = "protocolTreasuryAddress";
        aztecLabels[5] = "stakingAssetAddress";
        aztecLabels[6] = "coinIssuerAddress";
        aztecLabels[7] = "rewardDistributorAddress";
        aztecLabels[8] = "flushRewarderAddress";
        aztecLabels[9] = "verifierAddress";
        aztecLabels[10] = "rollupAddress";
        _log_section(json, aztecLabels);

        emit log("");

        emit log("=========== Genesis Sale Contracts =============");

        string[] memory genesisSaleLabels = new string[](12);
        genesisSaleLabels[0] = "atpFactory";
        genesisSaleLabels[1] = "atpRegistry";
        genesisSaleLabels[2] = "zkPassportProvider";
        genesisSaleLabels[3] = "predicateSanctionsProvider";
        genesisSaleLabels[4] = "predicateSanctionsProviderSale";
        genesisSaleLabels[5] = "predicateKYCProvider";
        genesisSaleLabels[6] = "soulboundToken";
        genesisSaleLabels[7] = "genesisSequencerSale";
        genesisSaleLabels[8] = "splitsWarehouse";
        genesisSaleLabels[9] = "pullSplitFactory";
        genesisSaleLabels[10] = "stakingRegistry";
        genesisSaleLabels[11] = "atpWithdrawableAndClaimableStaker";

        _log_section(json, genesisSaleLabels);

        emit log("=============== TWAP Contracts =================");

        string[] memory twapLabels = new string[](13);
        twapLabels[0] = "auctionFactory";
        twapLabels[1] = "auctionHook";
        twapLabels[2] = "predicateAuctionScreeningProvider";
        twapLabels[3] = "atpFactoryAuction";
        twapLabels[4] = "atpRegistryAuction";
        twapLabels[5] = "virtualAztecToken";
        twapLabels[6] = "twapAuction";
        twapLabels[7] = "tokenLauncher";
        twapLabels[8] = "permit2";
        twapLabels[9] = "virtualLBPFactory";
        twapLabels[10] = "virtualLBP";
        twapLabels[11] = "atpWithdrawableAndClaimableStaker";
        twapLabels[12] = "twapDateGatedRelayer";

        _log_section(json, twapLabels);

        emit log("################################################");
    }

    function _log_section(string memory _json, string[] memory _labels) internal {
        for (uint256 i = 0; i < _labels.length; i++) {
            _populate(_json, _labels[i]);
        }

        // We are going to log them such that no owners get in at the bottom.

        string[] memory noOwners = new string[](_labels.length);
        uint256 noOwnersIndex = 0;
        for (uint256 i = 0; i < _labels.length; i++) {
            if (owners[addresses[_labels[i]]] == address(0)) {
                noOwners[noOwnersIndex] = _labels[i];
                noOwnersIndex++;
            }
        }
        for (uint256 i = 0; i < _labels.length; i++) {
            if (owners[addresses[_labels[i]]] != address(0)) {
                _log_ownership(_labels[i]);
                emit log("");
            }
        }
        for (uint256 i = 0; i < noOwnersIndex; i++) {
            if (bytes(noOwners[i]).length == 0) {
                break;
            }
            _log_ownership(noOwners[i]);
            emit log("");
        }
    }

    function _log_ownership(string memory _label) internal {
        uint256 l = 36;
        address a = addresses[_label];
        address owner = owners[a];
        address pendingOwner = pendingOwners[a];

        string memory label = _label;
        while (bytes(label).length < l) {
            label = string.concat(label, " ");
        }
        emit log_named_address(label, a);

        if (owner != address(0)) {
            string memory ownerLabel = "  owner";
            while (bytes(ownerLabel).length < l) {
                ownerLabel = string.concat(ownerLabel, " ");
            }
            emit log_named_address(ownerLabel, owner);
            ownerLabel = "  ownerLabel";
            while (bytes(ownerLabel).length < l) {
                ownerLabel = string.concat(ownerLabel, " ");
            }

            emit log_named_string(ownerLabel, labels[owner]);
        }

        if (pendingOwner != address(0)) {
            string memory pendingOwnerLabel = "  pendingOwner";
            while (bytes(pendingOwnerLabel).length < l) {
                pendingOwnerLabel = string.concat(pendingOwnerLabel, " ");
            }
            emit log_named_address(pendingOwnerLabel, pendingOwner);
            pendingOwnerLabel = "  pendingOwnerLabel";
            while (bytes(pendingOwnerLabel).length < l) {
                pendingOwnerLabel = string.concat(pendingOwnerLabel, " ");
            }

            emit log_named_string(pendingOwnerLabel, labels[pendingOwner]);
        }
    }

    function _populate(string memory _json, string memory _key) internal {
        string memory key = string.concat(".", _key);
        address contractAddress = vm.parseJsonAddress(_json, key);
        address owner = _try_get_owner(contractAddress);
        address pendingOwner = _try_get_pending_owner(contractAddress);

        if (
            bytes(labels[contractAddress]).length != 0 || owners[contractAddress] != address(0)
                || addresses[_key] != address(0)
        ) {
            emit log_named_string("Contract already populated", _key);
        }

        labels[contractAddress] = _key;
        owners[contractAddress] = owner;
        pendingOwners[contractAddress] = pendingOwner;
        addresses[_key] = contractAddress;
    }

    function _try_get_owner(address contractAddress) public returns (address) {
        if (contractAddress.code.length == 0) {
            return address(0);
        }

        Ownable ow = Ownable(contractAddress);

        (bool success, bytes memory data) = address(ow).staticcall(abi.encodeWithSelector(ow.owner.selector));
        if (success) {
            // hit fallback
            if (data.length != 32) {
                return address(0);
            }
            return abi.decode(data, (address));
        }
        return address(0);
    }

    function _try_get_pending_owner(address contractAddress) public returns (address) {
        if (contractAddress.code.length == 0) {
            return address(0);
        }

        Ownable2Step ow = Ownable2Step(contractAddress);

        (bool success, bytes memory data) = address(ow).staticcall(abi.encodeWithSelector(ow.pendingOwner.selector));

        if (success) {
            // hit fallback
            if (data.length != 32) {
                return address(0);
            }
            return abi.decode(data, (address));
        }
        return address(0);
    }
}
