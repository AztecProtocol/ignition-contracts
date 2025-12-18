// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "@oz/access/Ownable.sol";
import {PredicateMessage} from "@predicate/interfaces/IPredicateClient.sol";
import {IPredicateClient} from "@predicate/interfaces/IPredicateClient.sol";
import {PredicateClient} from "@predicate/mixins/PredicateClient.sol";
import {IWhitelistProvider} from "./IWhitelistProvider.sol";

interface IPredicateProvider is IWhitelistProvider, IPredicateClient {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Events                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    event PolicySet(string indexed policyID);
    event PredicateManagerSet(address indexed predicateManager);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Errors                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    error PredicateProvider__AuthorizationFailed();
}

interface IPredicateAction {
    function predicateAttestation(address _provider, address _user) external;
}

contract PredicateProvider is IWhitelistProvider, IPredicateProvider, Ownable, PredicateClient {
    /// @notice The consumer of the provider - the soulbound contract
    address public consumer;

    /**
     * @notice Constructor
     * @param _owner The owner of the contract
     * @param _predicateManager The predicate manager address
     * @param _policyID The policy ID
     *
     * @dev Ownable
     * @dev PredicateClient
     */
    constructor(address _owner, address _predicateManager, string memory _policyID) Ownable(_owner) {
        _initPredicateClient(_predicateManager, _policyID);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Verify Logic                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Verify the authentication data
     *
     * Check against the existing policy that the user has completed a sanctions check
     *
     * @param _user The address of the user to verify
     * @param _auth The authentication data - PredicateMessage
     * @return bool True if the authentication data is valid
     */
    function verify(address _user, bytes memory _auth) external override(IWhitelistProvider) returns (bool) {
        // The call must come from the expected consumer, such that _user field cannot be spoofed
        require(msg.sender == consumer, WhitelistProvider__InvalidConsumer());

        PredicateMessage memory predicateMessage = abi.decode(_auth, (PredicateMessage));
        bytes memory encodedSigAndArgs =
            abi.encodeWithSelector(IPredicateAction.predicateAttestation.selector, address(this), _user);

        require(
            _authorizeTransaction(predicateMessage, encodedSigAndArgs, _user, 0),
            PredicateProvider__AuthorizationFailed()
        );

        return true;
    }

    /**
     * @notice Set the consumer address
     * @param _consumer The consumer address
     *
     * @dev onlyOwner
     */
    function setConsumer(address _consumer) external override(IWhitelistProvider) onlyOwner {
        consumer = _consumer;
        emit ConsumerSet(_consumer);
    }

    /**
     * @notice Set the policy ID
     * @param _policyID The policy ID
     *
     * @dev onlyOwner
     */
    function setPolicy(string memory _policyID) external override(IPredicateClient) onlyOwner {
        _setPolicy(_policyID);
        emit PolicySet(_policyID);
    }

    /**
     * @notice Set the predicate manager address
     * @param _predicateManager The predicate manager address
     *
     * @dev onlyOwner
     */
    function setPredicateManager(address _predicateManager) external override(IPredicateClient) onlyOwner {
        _setPredicateManager(_predicateManager);
        emit PredicateManagerSet(_predicateManager);
    }
}
