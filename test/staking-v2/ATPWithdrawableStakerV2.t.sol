// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

import {IRegistry as IATPRegistry, StakerVersion} from "@atp/Registry.sol";
import {IATPCore, IATPPeriphery} from "@atp/atps/base/IATP.sol";
import {IStaking} from "@aztec/core/interfaces/IStaking.sol";
import {Status} from "@aztec/core/libraries/rollup/StakingLib.sol";
import {IGSE} from "@aztec/governance/GSE.sol";
import {IGovernance} from "@aztec/governance/interfaces/IGovernance.sol";
import {Timestamp} from "@aztec/shared/libraries/TimeMath.sol";

import {StakingRegistry} from "src/staking-registry/StakingRegistry.sol";
import {ATPWithdrawableStakerV2} from "src/staking/ATPWithdrawableStakerV2.sol";
import {IATPWithdrawableAndClaimableStaker} from "src/staking/interfaces/IATPWithdrawableAndClaimableStaker.sol";
import {IATPWithdrawableStaker} from "src/staking/interfaces/IATPWithdrawableStaker.sol";
import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";

import {DeployATPWithdrawableStakerV2} from "script/deploy/staker/DeployATPWithdrawableStakerV2.s.sol";

interface IATP is IATPCore, IATPPeriphery {}

interface IVersioned {
    function getVersion() external view returns (uint256);
}

/**
 * @notice Mainnet fork test for making staking available to employee and investor ATPs.
 *         Run with `forge test --match-path test/staking-v2/* --fork-url $RPC_URL`
 */
contract ATPWithdrawableStakerV2Test is Test {
    address public constant ATP_REGISTRY_OWNER = 0x92Ba0FD39658105FaC4dF2B9BADE998B5816b350;

    IATP public constant EMPLOYEE_MATP = IATP(0xfbD2b11C906a97f5b51682fE13e80b282A9ea50C);
    IATP public constant EMPLOYEE_LATP = IATP(0x9ebDe774E213480E69c78760adD76604Ce156cE7);
    IATP public constant INVESTOR_LATP = IATP(0x8F48578604Cf32cE95653e6D7DE2A5640b42eCf1);

    uint256 public constant PROVIDER_ID = 2;

    StakerVersion public constant STAKER_VERSION = StakerVersion.wrap(1);

    DeployATPWithdrawableStakerV2 public deployer;
    ATPWithdrawableStakerV2 public implementation;

    IERC20 public token;
    StakingRegistry public stakingRegistry;
    IStaking public rollup;
    uint256 public rollupVersion;

    address public operator = makeAddr("operator");

    function setUp() public {
        if (block.chainid != 1) {
            vm.skip(true);
        }

        deployer = new DeployATPWithdrawableStakerV2();
        implementation = deployer.deploy();

        vm.startPrank(ATP_REGISTRY_OWNER);
        deployer.EMPLOYEE_ATP_REGISTRY().registerStakerImplementation(address(implementation));
        deployer.INVESTOR_ATP_REGISTRY().registerStakerImplementation(address(implementation));
        vm.stopPrank();

        token = deployer.AZTEC_TOKEN();
        stakingRegistry = StakingRegistry(address(deployer.STAKING_REGISTRY()));
        rollup = IStaking(deployer.ROLLUP_REGISTRY().getCanonicalRollup());
        rollupVersion = IVersioned(address(rollup)).getVersion();

        vm.warp(
            _max(
                deployer.EMPLOYEE_ATP_REGISTRY().getExecuteAllowedAt(),
                deployer.INVESTOR_ATP_REGISTRY().getExecuteAllowedAt()
            )
        );
    }

    function test_registeredOnBothRegistries() public view {
        IATPRegistry[2] memory registries = [deployer.EMPLOYEE_ATP_REGISTRY(), deployer.INVESTOR_ATP_REGISTRY()];
        for (uint256 i = 0; i < registries.length; i++) {
            assertEq(StakerVersion.unwrap(registries[i].getNextStakerVersion()), 2);
            assertEq(registries[i].getStakerImplementation(STAKER_VERSION), address(implementation));
        }
    }

    function test_employeeMATP_lifecycle() public {
        _lifecycle(EMPLOYEE_MATP, true);
    }

    function test_employeeLATP_lifecycle() public {
        _lifecycle(EMPLOYEE_LATP, false);
    }

    function test_investorLATP_lifecycle() public {
        _lifecycle(INVESTOR_LATP, true);
    }

    function test_noBeneficiaryWithdrawal() public {
        IATPWithdrawableAndClaimableStaker staker = _upgrade(EMPLOYEE_MATP);

        // Even with the full balance approved, there is no path to send tokens to the beneficiary
        address beneficiary = EMPLOYEE_MATP.getBeneficiary();
        uint256 balance = token.balanceOf(address(EMPLOYEE_MATP));
        vm.prank(beneficiary);
        EMPLOYEE_MATP.approveStaker(balance);

        vm.prank(operator);
        vm.expectRevert();
        staker.withdrawAllTokensToBeneficiary();
    }

    /**
     * @dev Upgrade, stake with a provider, activate, delegate, exit, and check every token is back in the ATP
     */
    function _lifecycle(IATP _atp, bool _moveWithLatestRollup) internal {
        address beneficiary = _atp.getBeneficiary();
        uint256 atpBalanceBefore = token.balanceOf(address(_atp));
        uint256 beneficiaryBalanceBefore = token.balanceOf(beneficiary);
        uint256 activationThreshold = rollup.getActivationThreshold();

        IATPWithdrawableStaker staker = IATPWithdrawableStaker(address(_upgrade(_atp)));

        vm.prank(beneficiary);
        _atp.approveStaker(activationThreshold);

        address attester =
            stakingRegistry.getValueAtIndexInQueue(PROVIDER_ID, stakingRegistry.getFirstIndexInQueue(PROVIDER_ID))
        .attester;
        (, uint16 takeRate,) = stakingRegistry.providerConfigurations(PROVIDER_ID);

        vm.prank(operator);
        staker.stakeWithProvider(rollupVersion, PROVIDER_ID, takeRate, beneficiary, _moveWithLatestRollup);
        assertEq(token.balanceOf(address(_atp)), atpBalanceBefore - activationThreshold);

        // Activate the attester
        vm.warp(block.timestamp + 1 days);
        rollup.flushEntryQueue();
        assertEq(uint256(rollup.getStatus(attester)), uint256(Status.VALIDATING));

        // Delegation works whether the attester is on the rollup or the bonus instance
        IGSE gse = IGSE(address(rollup.getGSE()));
        uint256 votingPowerBefore = gse.getVotingPower(beneficiary);
        vm.prank(operator);
        staker.delegate(rollupVersion, attester, beneficiary);
        assertEq(gse.getVotingPower(beneficiary), votingPowerBefore + activationThreshold);

        // Exit through the staker
        vm.prank(operator);
        staker.initiateWithdraw(rollupVersion, attester);
        // Finalizing also claims the governance withdrawal, which unlocks after the rollup exit delay
        uint256 withdrawalId = rollup.getExit(attester).withdrawalId;
        IGovernance governance = IGovernance(deployer.ROLLUP_REGISTRY().getGovernance());
        vm.warp(Timestamp.unwrap(governance.getWithdrawal(withdrawalId).unlocksAt) + 1);
        staker.finalizeWithdraw(rollupVersion, attester);

        assertEq(token.balanceOf(address(_atp)), atpBalanceBefore, "funds should return to the ATP");
        assertEq(token.balanceOf(beneficiary), beneficiaryBalanceBefore, "beneficiary should receive nothing");
    }

    function _upgrade(IATP _atp) internal returns (IATPWithdrawableAndClaimableStaker staker) {
        address beneficiary = _atp.getBeneficiary();

        vm.startPrank(beneficiary);
        _atp.upgradeStaker(STAKER_VERSION);
        _atp.updateStakerOperator(operator);
        vm.stopPrank();

        staker = IATPWithdrawableAndClaimableStaker(address(_atp.getStaker()));
    }

    function _max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _a : _b;
    }
}
