
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
import {IZKPassportProviderLegacy} from "./ZKPassportProviderLegacy.sol";
import {ZKPassportProviderLegacy} from "./ZKPassportProviderLegacy.sol";

interface IZKPassportProvider is IZKPassportProviderLegacy {
    function portNullifiers(bytes32[] memory _nullifier) external;
}

/**
 * @title ZKPassportProvider
 * @author Aztec-Labs
 * @notice A Provider that verifies a zk passport proof, keeping track of nullifier hashes.
 */
contract ZKPassportProvider is ZKPassportProviderLegacy, IZKPassportProvider {
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
        ZKPassportProviderLegacy(_consumer, _zkPassportVerifier, _domain, _scope)
    {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Verify Logic                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Verifies a zk passport proof
     * @param _user The user's address
     * @param _auth The authentication data
     * @return True if the proof is valid
     */
    function verify(address _user, bytes memory _auth) external override(ZKPassportProviderLegacy, IWhitelistProvider) returns (bool) {
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
        string[] memory excludedCountries = new string[](3);
        excludedCountries[0] = CUB;
        excludedCountries[1] = IRN;
        excludedCountries[2] = PKR;
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
      * @dev 
      * @param _nullifiers Unique identifiers to prefill into the list
      */
    function portNullifiers(bytes32[] memory _nullifiers) external override(IZKPassportProvider) onlyOwner {
      for (uint256 i; i < _nullifiers.length;) {
        nullifierHashes[_nullifiers[i]] = true;

        unchecked {
          ++i;
        }
      }
    }
}
