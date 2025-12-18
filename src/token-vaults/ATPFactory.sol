// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Ownable2Step, Ownable} from "@oz/access/Ownable2Step.sol";
import {Clones} from "@oz/proxy/Clones.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
import {ILATP, RevokableParams} from "./atps/linear/ILATP.sol";
import {IMATP, MilestoneId} from "./atps/milestone/IMATP.sol";
import {LATP} from "./atps/linear/LATP.sol";
import {MATP} from "./atps/milestone/MATP.sol";
import {INCATP} from "./atps/noclaim/INCATP.sol";
import {NCATP} from "./atps/noclaim/NCATP.sol";
import {Registry, IRegistry} from "./Registry.sol";

import {LATPFactory} from "./deployment-factories/LATPFactory.sol";
import {NCATPFactory} from "./deployment-factories/NCATPFactory.sol";
import {MATPFactory} from "./deployment-factories/MATPFactory.sol";

interface IATPFactory {
    event ATPCreated(address indexed beneficiary, address indexed atp, uint256 allocation);
    event MinterSet(address indexed minter, bool isMinter);

    error InvalidInputLength();
    error NotMinter();

    function createLATP(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
        external
        returns (ILATP);

    function createNCATP(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
        external
        returns (INCATP);

    function createMATP(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId) external returns (IMATP);

    function createLATPs(
        address[] memory _beneficiaries,
        uint256[] memory _allocations,
        RevokableParams[] memory _revokableParams
    ) external returns (ILATP[] memory);

    function createNCATPs(
        address[] memory _beneficiaries,
        uint256[] memory _allocations,
        RevokableParams[] memory _revokableParams
    ) external returns (INCATP[] memory);

    function createMATPs(
        address[] memory _beneficiaries,
        uint256[] memory _allocations,
        MilestoneId[] memory _milestoneIds
    ) external returns (IMATP[] memory);

    function recoverTokens(address _token, address _to, uint256 _amount) external;

    function setMinter(address _minter, bool _isMinter) external;

    function getRegistry() external view returns (IRegistry);

    function getToken() external view returns (IERC20);

    function predictLATPAddress(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
        external
        view
        returns (address);

    function predictNCATPAddress(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
        external
        view
        returns (address);

    function predictMATPAddress(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId)
        external
        view
        returns (address);
}

contract ATPFactory is Ownable2Step, IATPFactory {
    using SafeERC20 for IERC20;

    Registry internal immutable REGISTRY;
    IERC20 internal immutable TOKEN;

    LATP internal immutable LATP_IMPLEMENTATION;
    NCATP internal immutable NCATP_IMPLEMENTATION;
    MATP internal immutable MATP_IMPLEMENTATION;

    mapping(address => bool) public minter;

    modifier onlyMinter() {
        require(minter[msg.sender], NotMinter());
        _;
    }

    constructor(address __owner, IERC20 _token, uint256 _unlockCliffDuration, uint256 _unlockLockDuration)
        Ownable(__owner)
    {
        REGISTRY = new Registry(__owner, _unlockCliffDuration, _unlockLockDuration);
        TOKEN = _token;
        LATP_IMPLEMENTATION = LATPFactory.deployImplementation(IRegistry(address(REGISTRY)), TOKEN);
        NCATP_IMPLEMENTATION = NCATPFactory.deployImplementation(IRegistry(address(REGISTRY)), TOKEN);
        MATP_IMPLEMENTATION = MATPFactory.deployImplementation(IRegistry(address(REGISTRY)), TOKEN);

        minter[__owner] = true;
        emit MinterSet(__owner, true);
    }

    /**
     * @notice  Recover any token from the contract
     *
     * @dev     The caller must be the `owner`
     *
     * @dev     Does not support Ether as it is not an ERC20,
     *
     * @param _token   The token to rescue
     * @param _to   The address to rescue the tokens to
     * @param _amount   The amount of tokens to rescue
     */
    function recoverTokens(address _token, address _to, uint256 _amount) external override(IATPFactory) onlyOwner {
        IERC20(_token).safeTransfer(_to, _amount);
    }

    /**
     * @notice  Set the minter status of an address
     *
     * @dev     The caller must be the `owner`
     *
     * @param _minter The address to set the minter status of
     * @param _isMinter The minter status to set
     */
    function setMinter(address _minter, bool _isMinter) external override(IATPFactory) onlyOwner {
        minter[_minter] = _isMinter;
        emit MinterSet(_minter, _isMinter);
    }

    /**
     * @notice  Create and fund multiple LATPs
     *          Creates the LATPs using the `clones` library, initializes it and funds it.
     *
     * @dev     The caller must be a minter
     *
     * @param _beneficiaries The addresses of the beneficiaries
     * @param _allocations The amounts of tokens to allocate to the LATPs
     * @param _revokableParams The parameters for the accumulation lock and revoke beneficiary,
     *                         provide empty `LockParams` and `address(0)` as `revokeBeneficiary`
     *                         if the LATP are not revokable
     *
     * @return The LATPs
     */
    function createLATPs(
        address[] memory _beneficiaries,
        uint256[] memory _allocations,
        RevokableParams[] memory _revokableParams
    ) external virtual override(IATPFactory) onlyMinter returns (ILATP[] memory) {
        require(
            _beneficiaries.length == _allocations.length && _beneficiaries.length == _revokableParams.length,
            InvalidInputLength()
        );
        ILATP[] memory atps = new ILATP[](_beneficiaries.length);
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            atps[i] = createLATP(_beneficiaries[i], _allocations[i], _revokableParams[i]);
        }
        return atps;
    }

    /**
     * @notice  Create and fund multiple NCATPs
     *          Creates the NCATPs using the `clones` library, initializes it and funds it.
     *
     * @dev     The caller must be a `minter`
     *
     * @param _beneficiaries The addresses of the beneficiaries
     * @param _allocations The amounts of tokens to allocate to the NCATPs
     * @param _revokableParams The parameters for the accumulation lock and revoke beneficiary,
     *                         provide empty `LockParams` and `address(0)` as `revokeBeneficiary`
     *                         if the NCATP are not revokable
     *
     * @return The NCATPs
     */
    function createNCATPs(
        address[] memory _beneficiaries,
        uint256[] memory _allocations,
        RevokableParams[] memory _revokableParams
    ) external virtual override(IATPFactory) onlyMinter returns (INCATP[] memory) {
        require(
            _beneficiaries.length == _allocations.length && _beneficiaries.length == _revokableParams.length,
            InvalidInputLength()
        );
        INCATP[] memory atps = new INCATP[](_beneficiaries.length);
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            atps[i] = createNCATP(_beneficiaries[i], _allocations[i], _revokableParams[i]);
        }
        return atps;
    }

    /**
     * @notice  Create and fund multiple MATPs
     *          Creates the MATPs using the `clones` library, initializes it and funds it.
     *
     * @dev     The caller must be a `minter`
     *
     * @param _beneficiaries The addresses of the beneficiaries
     * @param _allocations The amounts of tokens to allocate to the MATPs
     * @param _milestoneIds The milestone IDs for the MATPs
     *
     * @return The MATPs
     */
    function createMATPs(
        address[] memory _beneficiaries,
        uint256[] memory _allocations,
        MilestoneId[] memory _milestoneIds
    ) external virtual override(IATPFactory) onlyMinter returns (IMATP[] memory) {
        require(
            _beneficiaries.length == _allocations.length && _beneficiaries.length == _milestoneIds.length,
            InvalidInputLength()
        );
        IMATP[] memory atps = new IMATP[](_beneficiaries.length);
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            atps[i] = createMATP(_beneficiaries[i], _allocations[i], _milestoneIds[i]);
        }
        return atps;
    }

    /**
     * @notice  Get the registry
     *
     * @return  The registry
     */
    function getRegistry() external view override(IATPFactory) returns (IRegistry) {
        return IRegistry(address(REGISTRY));
    }

    /**
     * @notice  Get the token
     *
     * @return  The token
     */
    function getToken() external view override(IATPFactory) returns (IERC20) {
        return TOKEN;
    }

    /**
     * @notice  Predict the address of an LATP
     *
     * @param _beneficiary   The address of the beneficiary
     * @param _allocation    The amount of tokens to allocate to the LATP
     * @param _revokableParams The parameters for the accumulation lock and revoke beneficiary, if the LATPs are revokable
     *
     * @return  The address of the LATP
     */
    function predictLATPAddress(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
        external
        view
        virtual
        override(IATPFactory)
        returns (address)
    {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
        return Clones.predictDeterministicAddress(address(LATP_IMPLEMENTATION), salt, address(this));
    }

    function predictNCATPAddress(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
        external
        view
        virtual
        override(IATPFactory)
        returns (address)
    {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
        return Clones.predictDeterministicAddress(address(NCATP_IMPLEMENTATION), salt, address(this));
    }

    function predictMATPAddress(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId)
        external
        view
        virtual
        override(IATPFactory)
        returns (address)
    {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _milestoneId));
        return Clones.predictDeterministicAddress(address(MATP_IMPLEMENTATION), salt, address(this));
    }

    /**
     * @notice  Create and funds a new LATP
     *          The LATP is created using the `Clones` library and then initialized.
     *          We deploy deterministically using the initialization params as the salt.
     *          When created, the LATP is funded with the `_allocation` amount of tokens.
     *
     *          This setup is done to keep gas costs low.
     *
     * @dev     The caller must be a `minter`
     *
     * @param _beneficiary   The address of the beneficiary
     * @param _allocation    The amount of tokens to allocate to the LATP
     * @param _revokableParams   The parameters for the accumulation lock, if the LATP is revokable
     *
     * @return  The LATP
     */
    function createLATP(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
        public
        virtual
        override(IATPFactory)
        onlyMinter
        returns (ILATP)
    {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
        LATP atp = LATP(Clones.cloneDeterministic(address(LATP_IMPLEMENTATION), salt));
        atp.initialize(_beneficiary, _allocation, _revokableParams);
        TOKEN.safeTransfer(address(atp), _allocation);
        emit ATPCreated(_beneficiary, address(atp), _allocation);
        return ILATP(address(atp));
    }

    /**
     * @notice  Create and funds a new NCATP (Non-Claimable ATP)
     *          The NCATP is created using the `Clones` library and then initialized.
     *          We deploy deterministically using the initialization params as the salt.
     *          When created, the NCATP is funded with the `_allocation` amount of tokens.
     *
     *          This setup is done to keep gas costs low.
     *
     * @dev     The caller must be a `minter`
     *
     * @param _beneficiary   The address of the beneficiary
     * @param _allocation    The amount of tokens to allocate to the NCATP
     * @param _revokableParams   The parameters for the accumulation lock, if the NCATP is revokable
     *
     * @return  The NCATP
     */
    function createNCATP(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
        public
        virtual
        override(IATPFactory)
        onlyMinter
        returns (INCATP)
    {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
        NCATP atp = NCATP(Clones.cloneDeterministic(address(NCATP_IMPLEMENTATION), salt));
        atp.initialize(_beneficiary, _allocation, _revokableParams);
        TOKEN.safeTransfer(address(atp), _allocation);
        emit ATPCreated(_beneficiary, address(atp), _allocation);
        return INCATP(address(atp));
    }

    /**
     * @notice  Create and funds a new MATP
     *          The MATP is created using the `Clones` library and then initialized.
     *          We deploy deterministically using the initialization params as the salt.
     *          When created, the MATP is funded with the `_allocation` amount of tokens.
     *
     *          This setup is done to keep gas costs low.
     *
     * @dev     The caller must be a `minter`
     *
     * @param _beneficiary   The address of the beneficiary
     * @param _allocation    The amount of tokens to allocate to the MATP
     * @param _milestoneId   The milestone ID for the MATP
     *
     * @return  The MATP
     */
    function createMATP(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId)
        public
        virtual
        override(IATPFactory)
        onlyMinter
        returns (IMATP)
    {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _milestoneId));
        MATP atp = MATP(Clones.cloneDeterministic(address(MATP_IMPLEMENTATION), salt));
        atp.initialize(_beneficiary, _allocation, _milestoneId);
        TOKEN.safeTransfer(address(atp), _allocation);
        emit ATPCreated(_beneficiary, address(atp), _allocation);
        return IMATP(address(atp));
    }
}
