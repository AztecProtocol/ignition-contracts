// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    ProofVerificationParams,
    BoundData,
    FaceMatchMode,
    OS
} from "@zkpassport/Types.sol";
import {ZKPassportHelper} from "@zkpassport/ZKPassportHelper.sol";
import {ZKPassportRootVerifier} from "@zkpassport/ZKPassportRootVerifier.sol";
import {IWhitelistProvider} from "./IWhitelistProvider.sol";

interface IZKPassportProviderLegacy is IWhitelistProvider {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Events                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    event DomainSet(string indexed domain);
    event ScopeSet(string indexed scope);
    event ZKPassportVerifierSet(address indexed zkPassportVerifier);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Errors                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    error ZKPassportProvider__InvalidProof();
    error ZKPassportProvider__SybilDetected(bytes32 _nullifier);
    error ZKPassportProvider__InvalidCountry();
    error ZKPassportProvider__InvalidAge();
    error ZKPassportProvider__InvalidBoundAddress();
    error ZKPassportProvider__InvalidBoundChainId();
    error ZKPassportProvider__InvalidDomain();
    error ZKPassportProvider__InvalidScope();
    error ZKPassportProvider__InvalidValidityPeriod();
    error ZKPassportProvider__ExtraDiscloseDataNonZero();
    error ZKPassportProvider__InvalidFaceMatch();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   Admin Functions                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function setZKPassportVerifier(address _zkPassportVerifier) external;
    function setDomain(string memory _domain) external;
    function setScope(string memory _scope) external;
}

/**
 * @title ZKPassportProvider
 * @author Aztec-Labs
 * @notice A Provider that verifies a zk passport proof, keeping track of nullifier hashes.
 */
contract ZKPassportProviderLegacy is IZKPassportProviderLegacy, Ownable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Constants                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Excluded countries
    string internal constant PKR = "PRK";
    string internal constant UKR = "UKR";
    string internal constant IRN = "IRN";
    string internal constant CUB = "CUB";

    // Minimum age
    uint8 public constant MIN_AGE = 18;

    // Validity period in seconds
    uint256 public constant VALIDITY_PERIOD = 7 days;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   State Variables                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    mapping(bytes32 nullifier => bool used) public nullifierHashes;

    /// @notice The zk passport verifier - contains zk proof verification logic
    ZKPassportRootVerifier public zkPassportVerifier;

    /// @notice The domain of the proof - the sale website
    string public domain;

    /// @notice The scope of the passport - the action being verified
    string public scope;

    /// @notice The consumer of the provider - the soulbound contract
    address public consumer;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     Constructor                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Constructor
     * @param _consumer The consumer of the provider - the soulbound contract
     * @param _zkPassportVerifier The address of the zk passport verifier
     * @param _domain The domain of the proof - the sale website
     * @param _scope The scope of the passport - the action being verified
     */
    constructor(address _consumer, address _zkPassportVerifier, string memory _domain, string memory _scope)
        Ownable(msg.sender)
    {
        zkPassportVerifier = ZKPassportRootVerifier(_zkPassportVerifier);
        consumer = _consumer;

        domain = _domain;
        emit DomainSet(_domain);

        scope = _scope;
        emit ScopeSet(_scope);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Verify Logic                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Verifies a zk passport proof
     * @param _user The user's address
     * @param _auth The authentication data
     * @return True if the proof is valid
     */
    function verify(address _user, bytes memory _auth) external virtual override(IWhitelistProvider) returns (bool) {
        // The call must come from the expected consumer, such that _user field cannot be spoofed
        require(msg.sender == consumer, WhitelistProvider__InvalidConsumer());

        ProofVerificationParams memory params = abi.decode(_auth, (ProofVerificationParams));

        require(params.serviceConfig.devMode == false, ZKPassportProvider__InvalidProof());
        require(
            keccak256(bytes(params.serviceConfig.domain)) == keccak256(bytes(domain)),
            ZKPassportProvider__InvalidDomain()
        );
        require(
            keccak256(bytes(params.serviceConfig.scope)) == keccak256(bytes(scope)), ZKPassportProvider__InvalidScope()
        );
        require(
            params.serviceConfig.validityPeriodInSeconds == VALIDITY_PERIOD, ZKPassportProvider__InvalidValidityPeriod()
        );

        (bool verified, bytes32 nullifier, ZKPassportHelper helper) = zkPassportVerifier.verify(params);

        require(verified, ZKPassportProvider__InvalidProof());
        require(nullifierHashes[nullifier] == false, ZKPassportProvider__SybilDetected(nullifier));
        nullifierHashes[nullifier] = true;

        // Bind data check
        BoundData memory boundData = helper.getBoundData(params.committedInputs);
        require(boundData.senderAddress == _user, ZKPassportProvider__InvalidBoundAddress());
        require(boundData.chainId == block.chainid, ZKPassportProvider__InvalidBoundChainId());
        require(bytes(boundData.customData).length == 0, ZKPassportProvider__ExtraDiscloseDataNonZero());

        // Age check
        bool isAgeValid = helper.isAgeAboveOrEqual(MIN_AGE, params.committedInputs);
        require(isAgeValid, ZKPassportProvider__InvalidAge());

        // Country exclusion check
        string[] memory excludedCountries = new string[](4);
        excludedCountries[0] = CUB;
        excludedCountries[1] = IRN;
        excludedCountries[2] = PKR;
        excludedCountries[3] = UKR;
        bool isCountryValid = helper.isNationalityOut(excludedCountries, params.committedInputs);
        require(isCountryValid, ZKPassportProvider__InvalidCountry());

        // reverts internally if the sanctions check fails
        helper.enforceSanctionsRoot(block.timestamp, true, params.committedInputs);

        // Face match check
        bool isFaceMatchValid = helper.isFaceMatchVerified(
            FaceMatchMode.STRICT, OS.ANY, params.committedInputs
        );
        require(isFaceMatchValid, ZKPassportProvider__InvalidFaceMatch());

        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    Admin Functions                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @dev Do not change this after launch as this could impact nullifiers
     * @param _zkPassportVerifier The address of the zk passport verifier
     */
    function setZKPassportVerifier(address _zkPassportVerifier) external override(IZKPassportProviderLegacy) onlyOwner {
        zkPassportVerifier = ZKPassportRootVerifier(_zkPassportVerifier);
        emit ZKPassportVerifierSet(_zkPassportVerifier);
    }

    /**
     * @dev Do not change this after launch as it will impact nullifiers
     * @param _domain The domain of the passport
     */
    function setDomain(string memory _domain) external override(IZKPassportProviderLegacy) onlyOwner {
        domain = _domain;
        emit DomainSet(_domain);
    }

    /**
     * @dev Do not change this after launch as it will impact nullifiers
     * @param _scope The scope of the passport
     */
    function setScope(string memory _scope) external override(IZKPassportProviderLegacy) onlyOwner {
        scope = _scope;
        emit ScopeSet(_scope);
    }

    /**
     * The consumer
     * @param _consumer The Address of the soulbound contract
     */
    function setConsumer(address _consumer) external override(IWhitelistProvider) onlyOwner {
        consumer = _consumer;
        emit ConsumerSet(_consumer);
    }
}