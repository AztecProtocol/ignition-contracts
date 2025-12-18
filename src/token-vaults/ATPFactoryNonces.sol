// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Clones} from "@oz/proxy/Clones.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
import {IATPFactory, ATPFactory} from "./ATPFactory.sol";
import {ILATP, RevokableParams} from "./atps/linear/ILATP.sol";
import {LATP} from "./atps/linear/LATP.sol";
import {IMATP, MilestoneId} from "./atps/milestone/IMATP.sol";
import {MATP} from "./atps/milestone/MATP.sol";
import {INCATP} from "./atps/noclaim/INCATP.sol";
import {NCATP} from "./atps/noclaim/NCATP.sol";
import {Nonces} from "./Nonces.sol";

interface IATPFactoryNonces is IATPFactory {
    function predictLATPAddressWithNonce(
        address _beneficiary,
        uint256 _allocation,
        RevokableParams memory _revokableParams,
        uint256 _nonce
    ) external view returns (address);

    function predictNCATPAddressWithNonce(
        address _beneficiary,
        uint256 _allocation,
        RevokableParams memory _revokableParams,
        uint256 _nonce
    ) external view returns (address);

    function predictMATPAddressWithNonce(
        address _beneficiary,
        uint256 _allocation,
        MilestoneId _milestoneId,
        uint256 _nonce
    ) external view returns (address);
}

contract ATPFactoryNonces is IATPFactoryNonces, ATPFactory, Nonces {
    using SafeERC20 for IERC20;

    constructor(address __owner, IERC20 _token, uint256 _unlockCliffDuration, uint256 _unlockLockDuration)
        ATPFactory(__owner, _token, _unlockCliffDuration, _unlockLockDuration)
    {}

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
        override(IATPFactory, ATPFactory)
        returns (address)
    {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));

        uint256 nonce = nonces(salt);
        salt = keccak256(abi.encode(salt, nonce));
        return Clones.predictDeterministicAddress(address(LATP_IMPLEMENTATION), salt, address(this));
    }

    /**
     * @notice  Predict the address of an LATP with a given nonce
     *
     * @param _beneficiary   The address of the beneficiary
     * @param _allocation    The amount of tokens to allocate to the LATP
     * @param _revokableParams The parameters for the accumulation lock and revoke beneficiary, if the LATPs are revokable
     * @param _nonce   The nonce to use for the prediction
     *
     * @return  The address of the LATP
     */
    function predictLATPAddressWithNonce(
        address _beneficiary,
        uint256 _allocation,
        RevokableParams memory _revokableParams,
        uint256 _nonce
    ) external view override(IATPFactoryNonces) returns (address) {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
        salt = keccak256(abi.encode(salt, _nonce));
        return Clones.predictDeterministicAddress(address(LATP_IMPLEMENTATION), salt, address(this));
    }

    /// @inheritdoc IATPFactory
    function predictNCATPAddress(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
        external
        view
        override(IATPFactory, ATPFactory)
        returns (address)
    {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));

        uint256 nonce = nonces(salt);
        salt = keccak256(abi.encode(salt, nonce));
        return Clones.predictDeterministicAddress(address(NCATP_IMPLEMENTATION), salt, address(this));
    }

    /**
     * @notice  Predict the address of an NCATP with a given nonce
     *
     * @param _beneficiary   The address of the beneficiary
     * @param _allocation    The amount of tokens to allocate to the NCATP
     * @param _revokableParams The parameters for the accumulation lock and revoke beneficiary, if the NCATP is revokable
     * @param _nonce   The nonce to use for the prediction
     *
     * @return  The address of the NCATP
     */
    function predictNCATPAddressWithNonce(
        address _beneficiary,
        uint256 _allocation,
        RevokableParams memory _revokableParams,
        uint256 _nonce
    ) external view override(IATPFactoryNonces) returns (address) {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
        salt = keccak256(abi.encode(salt, _nonce));
        return Clones.predictDeterministicAddress(address(NCATP_IMPLEMENTATION), salt, address(this));
    }

    /// @inheritdoc IATPFactory
    function predictMATPAddress(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId)
        external
        view
        virtual
        override(IATPFactory, ATPFactory)
        returns (address)
    {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _milestoneId));

        uint256 nonce = nonces(salt);
        salt = keccak256(abi.encode(salt, nonce));
        return Clones.predictDeterministicAddress(address(MATP_IMPLEMENTATION), salt, address(this));
    }

    function predictMATPAddressWithNonce(
        address _beneficiary,
        uint256 _allocation,
        MilestoneId _milestoneId,
        uint256 _nonce
    ) external view override(IATPFactoryNonces) returns (address) {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _milestoneId));
        salt = keccak256(abi.encode(salt, _nonce));
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
        override(IATPFactory, ATPFactory)
        onlyMinter
        returns (ILATP)
    {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));

        uint256 nonce = useNonce(salt);
        salt = keccak256(abi.encode(salt, nonce));

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
        override(IATPFactory, ATPFactory)
        onlyMinter
        returns (INCATP)
    {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));

        uint256 nonce = useNonce(salt);
        salt = keccak256(abi.encode(salt, nonce));

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
        override(IATPFactory, ATPFactory)
        onlyMinter
        returns (IMATP)
    {
        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _milestoneId));

        uint256 nonce = useNonce(salt);
        salt = keccak256(abi.encode(salt, nonce));

        MATP atp = MATP(Clones.cloneDeterministic(address(MATP_IMPLEMENTATION), salt));
        atp.initialize(_beneficiary, _allocation, _milestoneId);
        TOKEN.safeTransfer(address(atp), _allocation);
        emit ATPCreated(_beneficiary, address(atp), _allocation);
        return IMATP(address(atp));
    }
}
