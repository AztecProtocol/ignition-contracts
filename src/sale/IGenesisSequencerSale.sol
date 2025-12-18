// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

interface IGenesisSequencerSale {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Events                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    event SaleTokensPurchased(
        address indexed beneficiary, address indexed operator, address indexed atp, uint256 purchaseCostInEth
    );
    event SaleTimesUpdated(uint256 startTime, uint256 endTime);
    event SaleStarted(uint256 startTime, uint256 endTime);
    event SaleStopped();
    event PriceUpdated(uint256 newPrice);
    event TokensWithdrawn(address indexed to, address indexed token, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);
    event ScreeningProviderSet(address screeningProvider);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Errors                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    error GenesisSequencerSale__SaleNotEnabled();
    error GenesisSequencerSale__SaleNotStarted();
    error GenesisSequencerSale__SaleHasEnded();
    error GenesisSequencerSale__ZeroAddress();
    error GenesisSequencerSale__IncorrectETH();
    error GenesisSequencerSale__ETHTransferFailed();
    error GenesisSequencerSale__AlreadyPurchased();
    error GenesisSequencerSale__NoSoulboundToken();
    error GenesisSequencerSale__AddressScreeningFailed();

    // Constructor errors
    error GenesisSequencerSale__InvalidPrice();
    error GenesisSequencerSale__InvalidTimeRange();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Functions                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function purchase(address _beneficiary, bytes calldata _screeningData) external payable;
    function purchaseAndMintSoulboundToken(
        address _beneficiary,
        bytes32[] calldata _merkleProof,
        address _identityProvider,
        bytes calldata _identityData,
        bytes calldata _screeningData,
        bytes calldata _atpBeneficiaryScreeningData,
        uint256 _gridTileId
    ) external payable;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Admin Functions                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function startSale() external;
    function stopSale() external;
    function setPricePerLotInEth(uint256 _pricePerLot) external;
    function setSaleTimes(uint96 _saleStartTime, uint96 _saleEndTime) external;
    function setAddressScreeningProvider(address _addressScreeningProvider) external;
    function withdrawTokens(address _to, address _token, uint256 _amount) external;
    function withdrawETH(address _to, uint256 _amount) external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        View Functions                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function isSaleActive() external view returns (bool);
    function getPurchaseCostInEth() external view returns (uint256);
    function TOKEN_LOT_SIZE() external view returns (uint256);
    function SALE_TOKEN_PURCHASE_AMOUNT() external view returns (uint256);
}
