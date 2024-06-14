// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IStaking {
    /**
    * @dev Event emitted when staking token is deposited
    *
    * @param user The address of the user who deposited the tokens
    * @param amount The amount of tokens deposited
    */
    event Deposit(address indexed user, uint256 amount);

    /**
    * @dev Event emitted when staking token is withdrawn
    *
    * @param user The address of the user who withdrew the tokens
    * @param amount The amount of tokens withdrawn
    */
    event Withdraw(address indexed user, uint256 amount);

    /**
    * @dev Event emitted when rewards are claimed by the user
    * 
    * @param user The address of the user who claimed the rewards
    * @param amount The amount of rewards claimed
    */
    event Claim(address indexed user, uint256 amount);

    /**
     * @notice Deposit the amount of staking token to the pool.
     * @dev It deposits the specified amount of staking token to the pool.
     *
     * @param amount The amount of staking token to deposit.
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Withdraw the staked(deposited) amount of tokens for the caller.
     * @dev It withdraws the staked(deposited) tokens from the pool and transfers
     * the tokens to the caller's account.
     */
    function withdraw() external;

    /**
     * @notice Claim the accumulated rewards for the caller.
     * @dev It claims the accumulated rewards for the caller and transfers
     * the rewards to the caller's account.
     */
    function claim() external;

    /**
     * @notice Get the amount of claimable rewards for a user.
     * @dev It returns the amount of claimable rewards for a user.
     *
     * @param user The address of the user.
     * @return The amount of claimable rewards.
     */
    function claimable(address user) external view returns (uint256);
}
