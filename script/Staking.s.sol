// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "src/Staking.sol";
import "test/Mock/MockERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract StakingScript is Script {
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address stakeTokenAddress = vm.envAddress("STAKE_TOKEN_ADDRESS");
        bool deployMockERC20 = vm.envBool("DEPLOY_MOCK_ERC20");

        if (deployMockERC20 == true) {
            MockERC20 mockToken = new MockERC20();
            mockToken.mint(msg.sender, 1000 ether);

            stakeTokenAddress = address(mockToken);
            console.log("Stake token deployed to:", stakeTokenAddress);
        }

        uint256 rewardPerBlock = vm.envUint("REWARD_PER_BLOCK");
        Staking staking = new Staking(
            IERC20(address(stakeTokenAddress)),
            rewardPerBlock
        );

        vm.stopBroadcast();

        console.log("Staking contract deployed to:", address(staking));

        return address(staking);
    }
}
