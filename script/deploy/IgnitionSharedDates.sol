library IgnitionSharedDates {
    // The start timestamp of the auction + genesis sale
    uint256 public constant START_TIMESTAMP = 1763042400; // 13th Nov 2025 14:00 UTC  (9:00 UTC - 5 hours)
    // The end timestamp of the genesis sale
    uint256 public constant GENESIS_SALE_END_TIMESTAMP = 1764597600; // Monday, December 1, 2025 02:00:00 (UTC)

    // The EXPECTED start block number of the auction + genesis sale - this will have some variance
    uint256 public constant START_BLOCK_NUMBER = 23790741; // ~13th Nov 2025 14:00 UTC - (9:00 UTC - 5 hours)
    
    // The legnth of the contributor period in blocks
    // 13th Nov -> 1st Dec 
    uint40 public constant CONTRIBUTOR_PERIOD_PRE_BIDDING_LENGTH = 128534; // 18 days -  129600 blocks however we subtract 2% per week to account for missed slots so we remove 1066 blocks
    // 1st Dec -> 2nd Dec
    uint40 public constant CONTRIBUTOR_PERIOD_BIDDING_LENGTH = 7200; // 1 day

    uint40 public constant BLOCKS_12_HOURS = 3600;
    uint40 public constant BLOCKS_24_HOURS = 7200;
}