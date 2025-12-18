// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {IStaking} from "src/staking/rollup-system-interfaces/IStaking.sol";
import {MockGSE} from "test/mocks/staking/MockGSE.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {Constants} from "src/constants.sol";
import {BN254Lib} from "src/staking-registry/libs/BN254.sol";

contract MockRollup is IStaking, Ownable {
    // TODO: maybe just import the whole rollup???
    error RewardsNotClaimable();
    error AlreadyStaked();
    error AlreadyExiting();
    error NotExiting();
    error NotStaked();
    error NotTheWithdrawer(address _received, address _expected);

    IERC20 public immutable TOKEN;
    MockGSE public immutable GSE;

    bool public areRewardsClaimable = false;

    mapping(address attester => uint256 staked) public staked;
    mapping(address attester => uint256 rewards) public rewards;
    mapping(address attester => address recipient) public recipients;

    mapping(address attester => bool isStaked) public isStaked;
    mapping(address attester => bool isExiting) public isExiting;

    mapping(address attester => address withdrawer) public withdrawers;

    bool public shouldDepositFail = false;

    constructor(IERC20 _token, MockGSE _gse) Ownable(msg.sender) {
        TOKEN = _token;
        GSE = _gse;
    }

    function deposit(
        address _attester,
        address _withdrawer,
        BN254Lib.G1Point memory _publicKeyG1,
        BN254Lib.G2Point memory _publicKeyG2,
        BN254Lib.G1Point memory _signature,
        bool _moveWithRollup
    ) external {
        require(!isStaked[_attester], AlreadyStaked());

        uint256 activationThreshold = getActivationThreshold();

        TOKEN.transferFrom(msg.sender, address(this), activationThreshold);

        staked[_attester] += activationThreshold;
        withdrawers[_attester] = _withdrawer;

        isStaked[_attester] = true;

        // Mimic the queue failing and returning funds to the withdrawer
        if (shouldDepositFail) {
            TOKEN.transfer(_withdrawer, activationThreshold);
        }

        GSE.deposit(_attester, _withdrawer, _publicKeyG1, _publicKeyG2, _signature, _moveWithRollup);
    }

    // TODO: lines this up
    function initiateWithdraw(address _attester, address _recipient) external {
        address expectedWithdrawer = withdrawers[_attester];
        require(msg.sender == expectedWithdrawer, NotTheWithdrawer(msg.sender, expectedWithdrawer));

        require(isStaked[_attester], NotStaked());
        require(!isExiting[_attester], AlreadyExiting());

        recipients[_attester] = _recipient;
        isExiting[_attester] = true;
    }

    function finaliseWithdraw(address _attester) external {
        require(isExiting[_attester], NotExiting());

        address recipient = recipients[_attester];

        uint256 amount = staked[_attester];
        staked[_attester] = 0;

        isStaked[_attester] = false;
        isExiting[_attester] = false;

        TOKEN.transfer(recipient, amount);
    }

    function claimSequencerRewards(address _sequencer) external {
        require(areRewardsClaimable, "Rewards are not claimable");
        uint256 rewardAmount = rewards[_sequencer];
        rewards[_sequencer] = 0;
        TOKEN.transfer(_sequencer, rewardAmount);
    }

    function reward(address _attester, uint256 _amount) external onlyOwner {
        rewards[_attester] += _amount;
    }

    function getGSE() external view returns (address) {
        return address(GSE);
    }

    function setShouldDepositFail(bool _shouldDepositFail) external onlyOwner {
        shouldDepositFail = _shouldDepositFail;
    }

    function setAreRewardsClaimable(bool _areRewardsClaimable) external onlyOwner {
        areRewardsClaimable = _areRewardsClaimable;
    }

    function test() external virtual {
        // @dev To avoid this being included in the coverage results
        // https://github.com/foundry-rs/foundry/issues/2988#issuecomment-1437784542
    }

    function getActivationThreshold() public view override(IStaking) returns (uint256) {
        return GSE.ACTIVATION_THRESHOLD();
    }
}
