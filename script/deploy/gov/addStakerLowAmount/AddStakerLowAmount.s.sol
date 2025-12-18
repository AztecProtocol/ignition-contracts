// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Aztec Labs.
pragma solidity >=0.8.27;

import {Script} from "forge-std/Script.sol";
import {LATP} from "@atp/atps/linear/LATP.sol";
import {StakerVersion} from "@atp/Registry.sol";
import {IATPNonWithdrawableStaker} from "src/staking/ATPNonWithdrawableStaker.sol";
import {Governance} from "@aztec/governance/Governance.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

contract AddStakerLowAmount is Script {
    address constant LATP_ADDRESS = 0x0000000000000000000000000000000000000000;
    address constant SENDER = 0x0000000000000000000000000000000000000000;

    StakerVersion constant STAKER_VERSION = StakerVersion.wrap(1);
    uint256 constant AMOUNT = 200_000e18;
    uint256 constant PROPOSAL_ID = 0;
    uint256 constant WITHDRAWAL_ID = 0;

    uint256 constant BALANCE = 200_000e18;

    address GOVERNANCE_ADDRESS;
    address TOKEN_ADDRESS;

    function _loadJson() internal returns (string memory) {
        string memory chainId = vm.toString(block.chainid);
        string memory deploymentsDir = vm.envString("DEPLOYMENTS_DIR");
        string memory inputPath = string.concat(deploymentsDir, "/collective-l1-deployment-", chainId, ".json");
        return vm.readFile(inputPath);
    }

    function setUp() public {
        string memory json = _loadJson();
        TOKEN_ADDRESS = vm.parseJsonAddress(json, ".stakingAssetAddress");
        GOVERNANCE_ADDRESS = vm.parseJsonAddress(json, ".governanceAddress");
    }

    function addStakerLowAmount() public {
        uint256 balance = IERC20(TOKEN_ADDRESS).balanceOf(LATP_ADDRESS);
        vm.startBroadcast();
        LATP(LATP_ADDRESS).upgradeStaker(STAKER_VERSION);
        LATP(LATP_ADDRESS).updateStakerOperator(SENDER);
        LATP(LATP_ADDRESS).approveStaker(balance);
        vm.stopBroadcast();
    }

    function depositIntoGovernance() public {
        uint256 balance = IERC20(TOKEN_ADDRESS).balanceOf(LATP_ADDRESS);
        vm.startBroadcast(SENDER);
        IATPNonWithdrawableStaker(LATP_ADDRESS).depositIntoGovernance(balance);
        vm.stopBroadcast();
    }

    function voteInProposal() public {
        uint256 balance = IERC20(TOKEN_ADDRESS).balanceOf(LATP_ADDRESS);

        vm.startBroadcast(SENDER);
        IATPNonWithdrawableStaker(LATP_ADDRESS).voteInGovernance(PROPOSAL_ID, balance, true);
        vm.stopBroadcast();
    }

    function initiateWithdraw() public {
        address stakerAddress = address(LATP(LATP_ADDRESS).getStaker());
        uint256 power = Governance(GOVERNANCE_ADDRESS).powerNow(stakerAddress);

        vm.startBroadcast();
        IATPNonWithdrawableStaker(LATP_ADDRESS).initiateWithdrawFromGovernance(BALANCE);
        vm.stopBroadcast();
    }

    function finalizeWithdraw() public {
        vm.startBroadcast();
        Governance(GOVERNANCE_ADDRESS).finalizeWithdraw(WITHDRAWAL_ID);
        vm.stopBroadcast();
    }
}