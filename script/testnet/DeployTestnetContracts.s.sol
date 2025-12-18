// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Deploy the contracts that are required for the atp-indexer and frontends to run on the testnet

import {Test} from "forge-std/Test.sol";

import {ATPFactory} from "@atp/ATPFactory.sol";
import {Registry as ATPRegistry} from "@atp/Registry.sol";
import {ATPWithdrawableAndClaimableStaker} from "src/staking/ATPWithdrawableAndClaimableStaker.sol";
import {IRegistry as IRollupRegistry} from "lib/l1-contracts/src/governance/Registry.sol";
import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";
import {RevokableParams} from "@atp/ATPFactory.sol";
import {LockLib} from "@atp/libraries/LockLib.sol";
import {INCATP} from "@atp/atps/noclaim/INCATP.sol";
import {StakerVersion} from "@atp/Registry.sol";

import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

import {StakingRegistry, IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";

import {IERC20} from "@oz/token/ERC20/IERC20.sol";

interface MintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract DeployTestnetStakingRegistryAndATPScript is Test {
    address constant STAKING_ASSET_ADDRESS = 0x139d2a7a0881e16332d7D1F8DB383A4507E1Ea7A;
    address constant ROLLUP_REGISTRY_ADDRESS = 0x459498e6BF7967BAD0966353b691Ef4395432479;

    address constant PULL_SPLIT_FACTORY_ADDRESS = 0x6B9118074aB15142d7524E8c4ea8f62A3Bdb98f1;

    address constant TOKEN_ADMIN = 0xdfe19Da6a717b7088621d8bBB66be59F2d78e924;

    struct DeployedContracts {
        address atpFactory;
        address atpRegistry;
        address stakingRegistry;
        address atpWithdrawableAndClaimableStaker;
    }

    function run() public returns (DeployedContracts memory) {
        DeployedContracts memory deployedContracts;
        // Deploy the contracts that are required for the atp-indexer and frontends to run on the testnet

        vm.broadcast();
        ATPFactory atpFactory = new ATPFactory(msg.sender, IERC20(STAKING_ASSET_ADDRESS), 365 days, 365 days);
        deployedContracts.atpFactory = address(atpFactory);

        vm.broadcast();
        atpFactory.setMinter(msg.sender, true);

        ATPRegistry atpRegistry = ATPRegistry(address(atpFactory.getRegistry()));
        deployedContracts.atpRegistry = address(atpRegistry);

        // Set executable at timestamp to 1
        vm.broadcast();
        atpRegistry.setExecuteAllowedAt(1);

        vm.broadcast();
        StakingRegistry stakingRegistry = new StakingRegistry(
            IERC20(STAKING_ASSET_ADDRESS), PULL_SPLIT_FACTORY_ADDRESS, IRegistry(ROLLUP_REGISTRY_ADDRESS)
        );
        deployedContracts.stakingRegistry = address(stakingRegistry);

        vm.broadcast();
        ATPWithdrawableAndClaimableStaker atpWithdrawableAndClaimableStaker = new ATPWithdrawableAndClaimableStaker(
            IERC20(STAKING_ASSET_ADDRESS),
            IRegistry(ROLLUP_REGISTRY_ADDRESS),
            StakingRegistry(address(stakingRegistry)),
            block.timestamp + 1 days
        );
        deployedContracts.atpWithdrawableAndClaimableStaker = address(atpWithdrawableAndClaimableStaker);

        vm.broadcast();
        atpRegistry.registerStakerImplementation(address(atpWithdrawableAndClaimableStaker));

        scenario(deployedContracts);

        return deployedContracts;
    }

    modifier snapshotted() {
        uint256 snapshotId = vm.snapshot();
        _;
        vm.revertTo(snapshotId);
    }

    /// @notice Perform a stake delegation using the staking registry that has just been deployed
    function scenario(DeployedContracts memory deployedContracts) public snapshotted {
        address providerAdmin = makeAddr("provider admin");
        address atpRecipient = makeAddr("atp recipient");
        address providerRewardsRecipient = makeAddr("provider rewards recipient");
        address attester = makeAddr("attester");

        // Send the atp factory some tokens
        vm.prank(TOKEN_ADMIN);
        MintableERC20(STAKING_ASSET_ADDRESS).mint(deployedContracts.atpFactory, 1e24);

        // Mint an ncatp
        vm.prank(msg.sender);
        INCATP atp = INCATP(
            ATPFactory(deployedContracts.atpFactory)
                .createNCATP(
                    atpRecipient,
                    200_000e18,
                    RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
                )
        );

        // Upgrade the staker and approve to be staked
        vm.prank(atpRecipient);
        atp.upgradeStaker(StakerVersion.wrap(1));

        // Update the staker operator
        vm.prank(atpRecipient);
        atp.updateStakerOperator(atpRecipient);

        // Approve the staker to be staked
        vm.prank(atpRecipient);
        atp.approveStaker(200_000e18);

        // Add a provider to the staking registry
        vm.prank(providerAdmin);
        uint256 providerId = IStakingRegistry(address(deployedContracts.stakingRegistry))
            .registerProvider(providerAdmin, 1000, providerRewardsRecipient);

        IStakingRegistry.KeyStore[] memory keys = new IStakingRegistry.KeyStore[](1);
        keys[0] = IStakingRegistry.KeyStore({
            attester: attester,
            publicKeyG1: BN254Lib.G1Point({x: 0, y: 0}),
            publicKeyG2: BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
            proofOfPossession: BN254Lib.G1Point({x: 0, y: 0})
        });

        vm.prank(providerAdmin);
        IStakingRegistry(address(deployedContracts.stakingRegistry)).addKeysToProvider(1, keys);

        // Stake the atp
        ATPWithdrawableAndClaimableStaker staker = ATPWithdrawableAndClaimableStaker(address(atp.getStaker()));

        // Get  the rollup versiont
        uint256 rollupVersion = IRollupRegistry(ROLLUP_REGISTRY_ADDRESS).getCanonicalRollup().getVersion();

        vm.prank(atpRecipient);
        staker.stakeWithProvider(rollupVersion, providerId, 1000, atpRecipient, true);
    }
}
