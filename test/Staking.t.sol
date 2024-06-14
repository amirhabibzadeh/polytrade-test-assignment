// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Staking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Mock/MockERC20.sol";

contract StakingTest is Test {
    Staking public staking;
    MockERC20 public stakeToken;
    address public constant ALICE = address(1);
    address public constant BOB = address(2);
    address public constant JOHN = address(3);

    uint256 public constant REWARD_PER_BLOCK = 1 ether;
    uint256 public constant INITIAL_BALANCE = 1000 ether;

    event Deposit(address indexed staker, uint256 amount);
    event Withdraw(address indexed staker, uint256 amount);
    event Claim(address indexed staker, uint256 amount);

    error ERC20InsufficientBalance(
        address sender,
        uint256 balance,
        uint256 needed
    );
    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );

    function setUp() public {
        stakeToken = new MockERC20();
        staking = new Staking(IERC20(address(stakeToken)), REWARD_PER_BLOCK);

        stakeToken.mint(address(staking), INITIAL_BALANCE);
        stakeToken.mint(ALICE, INITIAL_BALANCE);
        stakeToken.mint(BOB, INITIAL_BALANCE);
        stakeToken.mint(JOHN, 9 ether);

        vm.prank(ALICE);
        stakeToken.approve(address(staking), INITIAL_BALANCE);

        vm.prank(BOB);
        stakeToken.approve(address(staking), INITIAL_BALANCE);
    }

    function testDeposit() public {
        vm.startPrank(ALICE);
        vm.expectEmit(true, true, false, true);
        emit Deposit(ALICE, 10 ether);

        staking.deposit(10 ether);
        vm.stopPrank();

        assertEq(staking.totalStakeCheckpoints(0), block.number);
        (uint256[] memory amounts, uint256[] memory stakeChanges, ) = staking.getStake(ALICE);
        uint256 lastAmount = amounts[amounts.length - 1];
        uint256 lastStakeChange = stakeChanges[stakeChanges.length - 1];
        assertEq(lastAmount, 10 ether);
        assertEq(lastStakeChange, block.number);
        assertEq(staking.claimable(ALICE), 0);
        assertEq(staking.blockNumber2TotalStaked(block.number), 10 ether);
    }

    function testDepositErrors() public {
        vm.startPrank(ALICE);
        vm.expectRevert("Staking: Zero amount");
        staking.deposit(0);
        vm.stopPrank();

        vm.startPrank(JOHN);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientAllowance.selector,
                address(staking),
                0,
                10 ether
            )
        );
        staking.deposit(10 ether);

        stakeToken.approve(address(staking), 10 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientBalance.selector,
                JOHN,
                9 ether,
                10 ether
            )
        );
        staking.deposit(10 ether);

        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(ALICE);
        staking.deposit(10 ether);
        vm.roll(block.number + 10);

        vm.expectEmit(true, true, false, true);
        emit Withdraw(ALICE, 10 ether);
        staking.withdraw();
        vm.stopPrank();

        assertEq(stakeToken.balanceOf(ALICE), INITIAL_BALANCE);
        
        (uint256[] memory amounts, uint256[] memory stakeChanges, ) = staking.getStake(ALICE);
        assertEq(amounts[amounts.length - 1], 0);
        assertEq(stakeChanges[stakeChanges.length - 1], block.number);
        
        assertEq(staking.claimable(ALICE), 10 ether);
        assertEq(staking.blockNumber2TotalStaked(block.number), 0);
        assertEq(staking.totalStakeCheckpoints(1), block.number);

    }

    function testWithdrawErros() public {
        vm.startPrank(ALICE);
        vm.expectRevert("Staking: Zero stake");
        staking.withdraw();
        vm.stopPrank();
    }

    function testClaim() public {
        vm.startPrank(ALICE);
        staking.deposit(10 ether);
        vm.roll(block.number + 10);
        assertEq(staking.claimable(ALICE), 10 ether);

        vm.expectEmit(true, true, false, true);
        emit Claim(ALICE, 10 ether);
        staking.claim();
        vm.stopPrank();

        assertEq(
            stakeToken.balanceOf(ALICE),
            INITIAL_BALANCE - 10 ether + 10 ether
        );
        (uint256[] memory amounts, uint256[] memory stakeChanges, uint256 claimCheckpoint) = staking.getStake(ALICE);
        assertEq(amounts[amounts.length - 1], 10 ether);
        assertEq(stakeChanges[stakeChanges.length - 1], 1);
        assertEq(claimCheckpoint, block.number);
        assertEq(staking.claimable(ALICE), 0);
    }

    function testClaimErros() public {
        vm.startPrank(ALICE);
        vm.expectRevert("Staking: Zero claimable");
        staking.claim();

        staking.deposit(1000 ether);
        vm.roll(block.number + 2000);
        staking.withdraw();
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientBalance.selector,
                address(staking),
                1000 ether,
                2000 ether
            )
        );
        staking.claim();
        vm.stopPrank();
    }

    function testClaimable() public {
        vm.startPrank(ALICE);
        staking.deposit(10 ether);
        vm.roll(block.number + 10);
        uint256 claimable = staking.claimable(ALICE);
        vm.stopPrank();

        assertEq(claimable, 10 ether);
    }

    function testMultipleUsers() public {
        vm.startPrank(ALICE);
        staking.deposit(10 ether);
        vm.stopPrank();

        vm.roll(block.number + 9);

        assertEq(staking.claimable(ALICE), 9 ether);

        vm.startPrank(BOB);
        staking.deposit(10 ether);
        vm.stopPrank();

        vm.roll(block.number + 10);

        vm.startPrank(ALICE);
        uint256 ALICEClaimable = staking.claimable(ALICE);
        staking.claim();
        vm.stopPrank();

        vm.startPrank(BOB);
        uint256 BOBClaimable = staking.claimable(BOB);
        staking.claim();
        vm.stopPrank();

        assertEq(ALICEClaimable, 14 ether);
        assertEq(BOBClaimable, 5 ether);

        assertEq(staking.claimable(ALICE), 0);
        assertEq(staking.claimable(BOB), 0);

        vm.roll(block.number + 10);

        assertEq(staking.claimable(ALICE), 5 ether);
        assertEq(staking.claimable(BOB), 5 ether);

        vm.startPrank(ALICE);
        staking.withdraw();
        vm.stopPrank();

        assertEq(staking.claimable(ALICE), 5 ether);
        assertEq(staking.claimable(BOB), 5 ether);

        vm.roll(block.number + 10);

        vm.startPrank(BOB);
        staking.withdraw();
        vm.stopPrank();

        assertEq(staking.claimable(ALICE), 5 ether);
        assertEq(staking.claimable(BOB), 15 ether);

        vm.startPrank(ALICE);
        staking.claim();
        vm.stopPrank();

        assertEq(staking.claimable(ALICE), 0);
        assertEq(staking.claimable(BOB), 15 ether);

        vm.startPrank(BOB);
        staking.claim();
        vm.stopPrank();

        assertEq(staking.claimable(ALICE), 0);
        assertEq(staking.claimable(BOB), 0);
    }

    function testWithLoopMutipleUsers() public {
        for (uint256 i = 0; i < 1000; i++) {
            vm.startPrank(ALICE);
            staking.deposit(0.001 ether);
            vm.stopPrank();

            vm.roll(block.number + 17);

            vm.startPrank(BOB);
            staking.deposit(0.001 ether);
            vm.stopPrank();

            vm.roll(block.number + 13);
        }

        assertEq(staking.claimable(ALICE), 124061316040274110153);
        assertEq(staking.claimable(BOB), 107061316040274110153);
    }
}
