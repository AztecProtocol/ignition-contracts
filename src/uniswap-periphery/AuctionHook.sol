// SPDX-License-Identifier: Apache-2.0
/* solhint-disable compiler-version */
pragma solidity ^0.8.26;

import {Ownable} from "@oz/access/Ownable.sol";
import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";
import {IValidationHook} from "@twap-auction/interfaces/IValidationHook.sol";
import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";

interface IAztecAuctionHook is IValidationHook {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Events                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    event AuctionSet(address indexed auction);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Errors                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    error AztecAuctionHook__ZeroAddress();
    error AztecAuctionHook__ContributorPeriodEndBlockInPast();
    error AztecAuctionHook__NotAuction();
    error AztecAuctionHook__OwnerMustBeSender();
    error AztecAuctionHook__MaxPurchaseLimitExceeded();

    error AztecAuctionHook__NotContributor();
    error AztecAuctionHook__NotSoulbound();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    Admin Functions                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function setAuction(IContinuousClearingAuction _auction) external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     View Functions                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function totalPurchased(address _sender) external view returns (uint256);
    function MAX_PURCHASE_LIMIT() external view returns (uint256);
    function CONTRIBUTOR_PERIOD_END_BLOCK() external view returns (uint256);
    function auction() external view returns (IContinuousClearingAuction);
    function SOULBOUND() external view returns (IIgnitionParticipantSoulbound);
}

contract AztecAuctionHook is IAztecAuctionHook, Ownable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Constants                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /// @notice The maximum amount of tokens one user can purchase in the auction
    uint256 public constant MAX_PURCHASE_LIMIT = 250 ether;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Immutables                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /// @notice The block at which the contributor period ends; and to which any soulbound holder may bid
    uint256 public immutable CONTRIBUTOR_PERIOD_END_BLOCK;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          State                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /// @notice The soulbound contract - containing a registry of sanction checks
    IIgnitionParticipantSoulbound public immutable SOULBOUND;

    /// @notice The auction contract address
    IContinuousClearingAuction public auction;

    mapping(address sender => uint256 totalPurchased) public totalPurchased;

    /**
     * @notice Constructor
     * @dev Reverts if the soulbound or auction is the zero address or if the contributor period block end is in the past
     * @dev Sets the soulbound, contributor period block end, and auction
     * @dev Emits an AuctionSet event
     */
    constructor(IIgnitionParticipantSoulbound _soulbound, uint256 _contributorPeriodBlockEnd) Ownable(msg.sender) {
        require(address(_soulbound) != address(0), AztecAuctionHook__ZeroAddress());
        require(_contributorPeriodBlockEnd > block.number, AztecAuctionHook__ContributorPeriodEndBlockInPast());

        SOULBOUND = _soulbound;
        CONTRIBUTOR_PERIOD_END_BLOCK = _contributorPeriodBlockEnd;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Functions                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /**
     * @notice Validate a bid
     * @dev MUST revert if the bid is invalid
     * param maxPrice The maximum price the bidder is willing to pay
     * @param _amount The amount of the bid (in ether)
     * @param _owner The owner of the bid
     * @param _sender The sender of the bid
     * param _hookData Additional data to pass to the hook required for validation
     */
    function validate(uint256, uint128 _amount, address _owner, address _sender, bytes calldata)
        external
        override(IValidationHook)
    {
        require(address(auction) != address(0), AztecAuctionHook__ZeroAddress()); // ContinuousClearingAuction has not been set yet
        require(msg.sender == address(auction), AztecAuctionHook__NotAuction());

        require(_owner == _sender, AztecAuctionHook__OwnerMustBeSender());

        // When we are below the contributor period block, the bidder must be a genesis sequencer or contributor
        if (block.number < CONTRIBUTOR_PERIOD_END_BLOCK) {
            require(SOULBOUND.hasGenesisSequencerTokenOrContributorToken(_sender), AztecAuctionHook__NotContributor());
        } else {
            // When we are above the contributor period block, the bidder must have any soulbound token
            require(SOULBOUND.hasAnyToken(_sender), AztecAuctionHook__NotSoulbound());
        }

        uint256 newPurchasedAmount = totalPurchased[_sender] + _amount;
        totalPurchased[_sender] = newPurchasedAmount;
        require(newPurchasedAmount <= MAX_PURCHASE_LIMIT, AztecAuctionHook__MaxPurchaseLimitExceeded());
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    Admin Functions                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Set the auction
     * @param _auction The new auction address
     * @dev Reverts if the caller is not the owner
     * @dev Emits an AuctionSet event
     */
    function setAuction(IContinuousClearingAuction _auction) external override(IAztecAuctionHook) onlyOwner {
        auction = _auction;
        emit AuctionSet(address(auction));
    }
}
