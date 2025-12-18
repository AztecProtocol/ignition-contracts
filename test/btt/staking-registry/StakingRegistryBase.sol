// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {StakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {SplitsWarehouse} from "@splits/SplitsWarehouse.sol";
import {PullSplitFactory} from "@splits/splitters/pull/PullSplitFactory.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";

// Mocks
import {MockRegistry} from "test/mocks/staking/MockRegistry.sol";
import {MockRollup} from "test/mocks/staking/MockRollup.sol";
import {MockGSE} from "test/mocks/staking/MockGSE.sol";
import {MockGovernance} from "test/mocks/staking/MockGovernance.sol";

// Libs
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

contract StakingRegistryBase is Test {
    // 0x splits related testing infrastructure
    SplitsWarehouse public splitsWarehouse;
    PullSplitFactory public pullSplitFactory;
    MockGovernance public governance;
    IERC20 public stakingAsset;

    StakingRegistry public stakingRegistry;
    MockRegistry public rollupRegistry;
    MockRollup public rollup;
    MockGSE public gse;

    function setUp() public virtual {
        stakingAsset = new MockERC20("Staking Asset", "STA");
        splitsWarehouse = new SplitsWarehouse("eth", "eth");
        pullSplitFactory = new PullSplitFactory(address(splitsWarehouse));

        governance = new MockGovernance(address(stakingAsset));
        rollupRegistry = new MockRegistry(address(governance));
        gse = new MockGSE();
        rollup = new MockRollup(stakingAsset, gse);
        rollupRegistry.addRollup(0, address(rollup));
        gse.addRollup(address(rollup));

        stakingRegistry = new StakingRegistry(stakingAsset, address(pullSplitFactory), rollupRegistry);
    }

    function makeKeyStore(address _attester) internal pure returns (IStakingRegistry.KeyStore memory) {
        return IStakingRegistry.KeyStore({
            attester: _attester,
            publicKeyG1: BN254Lib.G1Point({x: 0, y: 0}),
            publicKeyG2: BN254Lib.G2Point({x0: 0, x1: 0, y0: 0, y1: 0}),
            proofOfPossession: BN254Lib.G1Point({x: 0, y: 0})
        });
    }
}
