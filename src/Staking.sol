// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IStaking.sol";

contract Staking is IStaking {
    /// @dev The reward amount distributed per block.
    uint256 public immutable rewardPerBlock;

    /// @dev The token used for staking.
    IERC20 public immutable stakeToken;

    /// @dev Struct representing the stake information for an address.
    struct Stake {
        /// @dev The amount of tokens staked at each block number.
        uint256[] amount;
        /// @dev The block numbers at which the stake changes.
        uint256[] stakeChanges;
        /// @dev The block number at which the last claim was made.
        uint256 claimCheckpoint;
    }

    /// @dev Mapping of each staker's stake information.
    mapping(address => Stake) public stakers;

    /// @dev Mapping of the total staked amount at each block number.
    mapping(uint256 => uint256) public blockNumber2TotalStaked;

    /// @dev The block numbers at which the total staked amount changes.
    uint256[] public totalStakeCheckpoints;

    /// @dev Constructs a new Staking contract.
    /// @param _stakeToken The token used for staking.
    /// @param _rewardPerBlock The reward amount distributed per block.
    constructor(IERC20 _stakeToken, uint256 _rewardPerBlock) {
        stakeToken = _stakeToken;
        rewardPerBlock = _rewardPerBlock;
    }

    /// @inheritdoc IStaking
    function deposit(uint256 amount) external override {
        _deposit(amount);
    }

    /// @inheritdoc IStaking
    function withdraw() external override {
        _withdraw();
    }

    /// @inheritdoc IStaking
    function claim() external override {
        _claim();
    }

    /// @inheritdoc IStaking
    function claimable(address staker) public view override returns (uint256) {
        return _claimable(staker);
    }

    /**
     * @dev Returns the stake information of a staker.
     *
     * @param staker The address of the staker.
     * @return amount An array of the staked amounts of the staker.
     * @return stakeChanges An array of the block numbers when the stake changes.
     * @return claimCheckpoint The block number when the staker last claimed.
     */
    function getStake(
        address staker
    ) external view returns (uint256[] memory, uint256[] memory, uint256) {
        Stake storage stake = stakers[staker];
        return (stake.amount, stake.stakeChanges, stake.claimCheckpoint);
    }

    /**
     * @dev Deposits the specified amount of tokens to the staking contract.
     *
     * Emits a {Deposit} event with the sender and the amount deposited.
     *
     * @param amount The amount of tokens to deposit.
     */
    function _deposit(uint256 amount) internal {
        require(amount > 0, "Staking: Zero amount");
        emit Deposit(msg.sender, amount);

        Stake storage stake = stakers[msg.sender];
        stake.amount.push(amount);
        stake.stakeChanges.push(block.number);

        uint256 lastCheckpoint = totalStakeCheckpoints.length == 0
            ? 0
            : totalStakeCheckpoints[totalStakeCheckpoints.length - 1];
        blockNumber2TotalStaked[block.number] =
            blockNumber2TotalStaked[lastCheckpoint] +
            amount;
        totalStakeCheckpoints.push(block.number);

        require(
            stakeToken.transferFrom(msg.sender, address(this), amount),
            "Staking: Transfer failed"
        );
    }

    /**
     * @dev Withdraws the staked tokens from the staking contract.
     *
     * Emits a {Withdraw} event with the sender and the amount withdrawn.
     *
     * Requirements:
     * - The staker must have a non-zero stake.
     */
    function _withdraw() internal {
        Stake storage stakerStake = stakers[msg.sender];
        uint256 withdrawAmount = stakerStake.amount.length == 0
            ? 0
            : stakerStake.amount[stakerStake.amount.length - 1];
        require(withdrawAmount > 0, "Staking: Zero stake");

        emit Withdraw(msg.sender, withdrawAmount);

        uint256 lastCheckpoint = totalStakeCheckpoints.length == 0
            ? 0
            : totalStakeCheckpoints[totalStakeCheckpoints.length - 1];
        blockNumber2TotalStaked[block.number] =
            blockNumber2TotalStaked[lastCheckpoint] -
            withdrawAmount;
        totalStakeCheckpoints.push(block.number);

        stakerStake.amount.push(0);
        stakerStake.stakeChanges.push(block.number);

        require(
            stakeToken.transfer(msg.sender, withdrawAmount),
            "Staking: Transfer failed"
        );
    }

    /**
     * @dev Claims the claimable rewards for the staker.
     *
     * Emits a {Claim} event with the sender and the amount claimed.
     *
     * Requirements:
     * - The staker must have a non-zero claimable amount.
     */
    function _claim() internal {
        uint256 claimableAmount = _claimable(msg.sender);
        require(claimableAmount > 0, "Staking: Zero claimable");

        emit Claim(msg.sender, claimableAmount);

        stakers[msg.sender].claimCheckpoint = block.number;

        require(
            stakeToken.transfer(msg.sender, claimableAmount),
            "Staking: Transfer failed"
        );
    }

    /**
     * @dev Returns the claimable rewards for the staker.
     *
     * This function calculates the claimable rewards based on the staking history of the user.
     *
     * @param staker The address of the staker.
     * @return The claimable rewards.
     */
    function _claimable(address staker) internal view returns (uint256) {
        uint256 totalStakeCheckpointsLength = totalStakeCheckpoints.length;

        if (totalStakeCheckpointsLength == 0) {
            return 0;
        }

        Stake storage stakerStake = stakers[staker];
        if (stakerStake.stakeChanges.length == 0) {
            return 0;
        }

        uint256 claimableReward = 0;
        uint256 previousBlock = stakerStake.claimCheckpoint;
        uint256 previousTotalStake = 0;
        uint256 previousUserStake = 0;
        for (uint256 i = totalStakeCheckpointsLength; i > 0; i--) {
            uint256 blockNumber = totalStakeCheckpoints[i - 1];
            if (blockNumber <= previousBlock) {
                previousTotalStake = blockNumber2TotalStaked[blockNumber];
                break;
            }
        }

        for (uint256 j = stakerStake.stakeChanges.length; j > 0; j--) {
            if (stakerStake.stakeChanges[j - 1] <= previousBlock) {
                previousUserStake = stakerStake.amount[j - 1];
                break;
            }
        }

        for (uint256 i = 0; i < totalStakeCheckpointsLength; i++) {
            uint256 blockNumber = totalStakeCheckpoints[i];
            if (blockNumber <= stakerStake.claimCheckpoint) {
                continue;
            }

            uint256 totalStaked = blockNumber2TotalStaked[blockNumber];

            uint256 stakerStakeAtBlock = 0;
            for (uint256 j = 0; j < stakerStake.stakeChanges.length; j++) {
                if (stakerStake.stakeChanges[j] <= blockNumber) {
                    stakerStakeAtBlock = stakerStake.amount[j];
                } else {
                    break;
                }
            }

            if (previousBlock != 0) {
                uint256 blockDiff = blockNumber - previousBlock;
                if (previousTotalStake > 0) {
                    claimableReward +=
                        (blockDiff * rewardPerBlock * previousUserStake) /
                        previousTotalStake;
                }
            }

            previousBlock = blockNumber;
            previousTotalStake = totalStaked;
            previousUserStake = stakerStakeAtBlock;
        }

        uint256 currentBlock = block.number;
        if (previousBlock != 0 && previousTotalStake > 0) {
            uint256 blockDiff = currentBlock - previousBlock;
            claimableReward +=
                (blockDiff * rewardPerBlock * previousUserStake) /
                previousTotalStake;
        }

        return claimableReward;
    }
}
