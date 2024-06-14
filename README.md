# Staking Contract

This repository contains a Solidity smart contract for a staking mechanism, along with a mock ERC20 token for testing and deployment scripts using the Foundry framework.

## Overview

The staking contract allows users to:
- Deposit tokens to earn rewards.
- Withdraw staked tokens along with earned rewards.
- Claim accumulated rewards without withdrawing the staked tokens.

The rewards are distributed proportionally based on the number of blocks the tokens are staked.

## Contracts

### Staking.sol

The `Staking` contract implements the staking functionality. It includes methods for depositing, withdrawing, and claiming rewards.

### MockERC20.sol

A simple mock ERC20 token contract for testing purposes.

## Interfaces

### IStaking.sol

An interface defining the basic functions for the staking contract.

## Deployment

### Prerequisites

Ensure you have Foundry installed. If not, you can install it using the following command:
```sh
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Environment Variables
```sh
cp .env.example .env
```

### Deployment Script

The deployment script is located at `script/StakingScript.sol`. This script deploys the mock ERC20 token and the staking contract.

To deploy the contracts, run the following command:
#### Localy:
```
anvil
```
Then
```sh
forge script script/Staking.s.sol:StakingScript --rpc-url http://localhost:8545 --broadcast
```
#### Onchain:
```sh
forge script script/Staking.s.sol:StakingScript --rpc-url <your-rpc-url> --broadcast --verify
```
Replace `<your-rpc-url>` with the URL of the Ethereum node you are using (e.g., from Infura or Alchemy).

## Testing

The test suite is located in the `test` directory and uses the Foundry framework.

### Running Tests

To run the tests, use the following command:
```sh
forge test
```

### Coverage
Please ensure that lcov is installed beforehand.
```shell
$ forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage
```

## Contributions

Feel free to submit issues, fork the repository and send pull requests for any features, bug fixes, or enhancements.

## License

This project is licensed under the MIT License.