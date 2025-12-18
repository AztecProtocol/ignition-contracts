// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {ERC1967Proxy} from "@oz/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@oz/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@oz/utils/math/Math.sol";
import {SafeCast} from "@oz/utils/math/SafeCast.sol";
import {Lock, LockLib} from "./../../libraries/LockLib.sol";
import {IRegistry, StakerVersion, MilestoneId, MilestoneStatus} from "./../../Registry.sol";
import {IBaseStaker} from "./../../staker/BaseStaker.sol";
import {IMATPCore, IATPCore} from "./IMATP.sol";

/**
 * @title   Milestone Aztec Token Position Core
 * @notice  The core logic of the Milestone Aztec Token Position
 * @dev     This contract is abstract and cannot be deployed on its own.
 *          It is meant to be inherited by the `MATP` contract.
 *          MUST be deployed using the `ATPFactory` contract.
 */
abstract contract MATPCore is IMATPCore {
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using LockLib for Lock;

    IERC20 internal immutable TOKEN;
    IRegistry internal immutable REGISTRY;

    uint256 internal allocation;

    // 160 + 96 = 256
    address internal beneficiary;
    MilestoneId internal milestoneId;

    IBaseStaker internal staker;
    address internal operator;

    uint256 internal claimed = 0;
    bool internal isRevoked = false;

    /**
     * @dev     The caller must be the beneficiary, or if the milestone have failed it must be the revoker
     */
    modifier onlyBeneficiary() {
        address _beneficiary = getBeneficiary();
        require(msg.sender == _beneficiary, NotBeneficiary(msg.sender, _beneficiary));
        _;
    }

    /**
     * @dev     Since we are using the `Clones` library to create the ATP's to use
     *          we can't use the constructor to initialize the individual ones, but
     *          we can use it to initialize values that will be shared across all the clones.
     *
     * @param _registry   The registry
     * @param _token      The token
     */
    constructor(IRegistry _registry, IERC20 _token) {
        require(address(_registry) != address(0), InvalidRegistry(address(_registry)));
        require(address(_token) != address(0), InvalidTokenAddress(address(_token)));

        TOKEN = _token;
        REGISTRY = _registry;

        staker = IBaseStaker(address(0xdead));
    }

    /**
     * @notice  Initialize the Aztec Token Position
     *          Creates a `Staker`, sets the `beneficiary` and `allocation`
     *          If the ATP is revokable, it will set the `accumulation` lock as well
     *
     * @dev     If run twice, the `staker` will already be set and this will revert
     *          with the `AlreadyInitialized` error
     *
     * @dev     When done by the `ATPFactory` this will happen in the same transaction as ATP creation
     *
     * @param _beneficiary              The address of the beneficiary
     * @param _allocation               The amount of tokens to allocate to the ATP
     * @param _milestoneId              The milestone id
     */
    function initialize(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId)
        external
        override(IMATPCore)
    {
        require(address(staker) == address(0), AlreadyInitialized());
        require(_beneficiary != address(0), InvalidBeneficiary(address(0)));
        require(_allocation > 0, AllocationMustBeGreaterThanZero());

        require(
            REGISTRY.getMilestoneStatus(_milestoneId) == MilestoneStatus.Pending,
            IRegistry.InvalidMilestoneStatus(_milestoneId)
        );

        beneficiary = _beneficiary;
        milestoneId = _milestoneId;
        allocation = _allocation;
        staker = createStaker();
    }

    /**
     * @notice  Upgrade the staker contract to a new version
     *
     * @param _version The version of the staker to upgrade to
     */
    function upgradeStaker(StakerVersion _version) external override(IATPCore) onlyBeneficiary {
        address impl = REGISTRY.getStakerImplementation(_version);
        UUPSUpgradeable(address(staker)).upgradeToAndCall(impl, "");

        require(staker.getATP() == address(this), InvalidUpgrade());

        emit StakerUpgraded(_version);
    }

    /**
     * @notice  Cancel the accumulation of assets
     *
     * @return  The amount of tokens revoked
     */
    function revoke() external override(IATPCore) returns (uint256) {
        require(!isRevoked, NotRevokable());
        require(REGISTRY.getMilestoneStatus(milestoneId) == MilestoneStatus.Pending, NotRevokable());
        address revoker = REGISTRY.getRevoker();
        require(msg.sender == revoker, NotRevoker(msg.sender, revoker));

        isRevoked = true;

        emit Revoked(allocation);

        return allocation;
    }

    /**
     * @notice  Rescue funds that have been sent to the contract by mistake
     *          Allows the beneficiary to transfer funds that are not unlock token from the contract.
     *
     * @param _asset  The asset to rescue
     * @param _to     The address to send the assets to
     */
    function rescueFunds(address _asset, address _to) external override(IATPCore) {
        require(_asset != address(TOKEN), InvalidAsset(_asset));
        require(msg.sender == beneficiary, NotBeneficiary(msg.sender, beneficiary));
        IERC20 asset = IERC20(_asset);
        uint256 amount = asset.balanceOf(address(this));
        asset.safeTransfer(_to, amount);

        emit Rescued(_asset, _to, amount);
    }

    /**
     * @notice  Authorizes the staker contract for the specified amount.
     *
     * @param _allowance The amount of tokens to authorize the staker contract for
     */
    function approveStaker(uint256 _allowance) external override(IATPCore) onlyBeneficiary {
        // slither-disable-start block-timestamp
        // As we are not relying on block.timestamp for randomness but merely for when we will toggle
        // the EXECUTE_ALLOWED_AT flag, and time will only ever increase, we can safely ignore the warning.
        uint256 executeAllowedAt = REGISTRY.getExecuteAllowedAt();
        require(block.timestamp >= executeAllowedAt, ExecutionNotAllowedYet(block.timestamp, executeAllowedAt));
        // slither-disable-end block-timestamp

        TOKEN.approve(address(staker), _allowance);

        emit ApprovedStaker(_allowance);
    }

    /**
     * @notice  Claim the amount of tokens that are available for the owner to claim.
     *
     * @dev     The `caller` must be the `beneficiary`
     *
     * @return  The amount of tokens claimed
     */
    function claim() external override(IATPCore) onlyBeneficiary returns (uint256) {
        uint256 amount = getClaimable();
        require(amount > 0, NoClaimable());

        claimed += amount;

        TOKEN.safeTransfer(msg.sender, amount);

        emit Claimed(amount);
        return amount;
    }

    /**
     * @notice  Update the operator of the staker contract
     *
     * @param _operator The address of the new operator
     */
    function updateStakerOperator(address _operator) public override(IATPCore) onlyBeneficiary {
        require(!isRevoked && REGISTRY.getMilestoneStatus(milestoneId) != MilestoneStatus.Failed, RevokedOrFailed());

        operator = _operator;
        emit StakerOperatorUpdated(_operator);
    }

    /**
     * @notice Compute the amount of tokens that can be claimed.
     *
     * @return  The amount of tokens that can be claimed
     */
    function getClaimable() public view override(IATPCore) returns (uint256) {
        MilestoneStatus status = REGISTRY.getMilestoneStatus(milestoneId);
        if (isRevoked || status == MilestoneStatus.Failed) {
            // When revoked or milestone failed, the lock is ignored as it is the revoker
            // claiming, and it should be able to bypass these
            return TOKEN.balanceOf(address(this));
        }
        if (status != MilestoneStatus.Succeeded) {
            return 0;
        }

        Lock memory globalLock = getGlobalLock();
        uint256 unlocked = globalLock.hasEnded(block.timestamp)
            ? type(uint256).max
            : (globalLock.unlockedAt(block.timestamp) - claimed);

        return Math.min(TOKEN.balanceOf(address(this)), unlocked);
    }

    /**
     * @notice  Get the global unlock schedule lock
     *
     * @return  The global lock
     */
    function getGlobalLock() public view override(IATPCore) returns (Lock memory) {
        return LockLib.createLock(REGISTRY.getGlobalLockParams(), allocation);
    }

    /**
     * @notice  Get the beneficiary of the ATP
     *          If the milestone has failed or ATP was revoked, the beneficiary is the revoker
     *
     * @return  The beneficiary
     */
    function getBeneficiary() public view override(IATPCore) returns (address) {
        if (isRevoked || REGISTRY.getMilestoneStatus(milestoneId) == MilestoneStatus.Failed) {
            return REGISTRY.getRevoker();
        }
        return beneficiary;
    }

    /**
     * @notice  Get the operator of the staker contract
     *          If the milestone has failed or ATP was revoked, the operator is the revoker operator
     *
     * @return  The operator
     */
    function getOperator() public view override(IATPCore) returns (address) {
        if (isRevoked || REGISTRY.getMilestoneStatus(milestoneId) == MilestoneStatus.Failed) {
            return REGISTRY.getRevokerOperator();
        }
        return operator;
    }

    /**
     * @notice  Create a new staker contract with the `ERC1967Proxy`
     *          the initial implementation used will the be `BaseStaker`
     *
     * @return  The new staker contract
     */
    function createStaker() private returns (IBaseStaker) {
        address impl = REGISTRY.getStakerImplementation(StakerVersion.wrap(0));
        ERC1967Proxy proxy = new ERC1967Proxy(impl, abi.encodeCall(IBaseStaker.initialize, address(this)));
        IBaseStaker _staker = IBaseStaker(address(proxy));
        emit StakerInitialized(_staker);
        return _staker;
    }
}
