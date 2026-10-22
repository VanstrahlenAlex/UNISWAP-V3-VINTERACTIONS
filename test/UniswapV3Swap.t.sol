// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test, console2} from "forge-std/Test.sol";
import {UniswapV3Swap} from "../src/UniswapV3Swap.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/// @title UniswapV3SwapTest - Fork tests against real Uniswap V3 on Ethereum mainnet
/// @notice These tests fork mainnet and interact with the real Uniswap V3 contracts.
///
/// TO RUN THESE TESTS (pick one):
///
///   1. Using a public RPC (free, no API key needed):
///      forge test --fork-url https://ethereum-rpc.publicnode.com -vvv
///
///   2. Using Alchemy (faster, requires free API key from https://www.alchemy.com):
///      forge test --fork-url https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY -vvv
///
///   3. Using an env variable + foundry.toml [rpc_endpoints]:
///      export MAINNET_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
///      forge test --fork-url mainnet -vvv
///
contract UniswapV3SwapTest is Test {
    // ── Mainnet Addresses ─────────────────────────────
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    // ── Fee Tiers ─────────────────────────────────────
    uint24 constant FEE_LOW = 500; //   0.05%
    uint24 constant FEE_MEDIUM = 3000; // 0.30%
    uint24 constant FEE_HIGH = 10000; //  1.00%

    event SwapExecuted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    UniswapV3Swap swap;
    address user = makeAddr("user");

    function setUp() public {
        swap = new UniswapV3Swap(SWAP_ROUTER);

        // Fund the user with every token the tests spend
        deal(WETH, user, 10 ether);
        deal(DAI, user, 100_000 ether);

        // The user lets our contract pull tokens on their behalf
        vm.startPrank(user);
        IERC20(WETH).approve(address(swap), type(uint256).max);
        IERC20(DAI).approve(address(swap), type(uint256).max);
        vm.stopPrank();
    }

    // ==============================================================================
    // DEPLOYMENT
    // ==============================================================================

    function test_Constructor_SetsRouter() public view {
        assertEq(address(swap.ROUTER()), SWAP_ROUTER);
    }

    // ==============================================================================
    // EXACT INPUT SINGLE - Sell exact amount, get maximum output
    // ==============================================================================

    function test_ExactInputSingle_WethToUsdc() public {
        uint256 amountIn = 1 ether;
        uint256 wethBefore = IERC20(WETH).balanceOf(user);
        uint256 usdcBefore = IERC20(USDC).balanceOf(user);

        vm.prank(user);
        uint256 amountOut = swap.SwapExactInputSingle(WETH, USDC, FEE_MEDIUM, amountIn, 1);

        console2.log("1 WETH -> USDC:", amountOut);

        assertGt(amountOut, 0, "no USDC received");
        // Exactly the requested input was sold
        assertEq(wethBefore - IERC20(WETH).balanceOf(user), amountIn, "WETH spent != amountIn");
        // The user got exactly what the router reported
        assertEq(IERC20(USDC).balanceOf(user) - usdcBefore, amountOut, "USDC received != amountOut");
    }

    function test_ExactInputSingle_LeavesNoTokensInContract() public {
        vm.prank(user);
        swap.SwapExactInputSingle(WETH, USDC, FEE_MEDIUM, 1 ether, 1);

        assertEq(IERC20(WETH).balanceOf(address(swap)), 0, "WETH stuck in contract");
        assertEq(IERC20(USDC).balanceOf(address(swap)), 0, "USDC stuck in contract");
    }

    function test_ExactInputSingle_EmitsSwapExecuted() public {
        // Check only the two indexed topics; amounts depend on the forked pool state
        vm.expectEmit(true, true, false, false, address(swap));
        emit SwapExecuted(WETH, USDC, 1 ether, 0);

        vm.prank(user);
        swap.SwapExactInputSingle(WETH, USDC, FEE_MEDIUM, 1 ether, 1);
    }

    function test_ExactInputSingle_RevertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(UniswapV3Swap.ZeroAmount.selector);
        swap.SwapExactInputSingle(WETH, USDC, FEE_MEDIUM, 0, 0);
    }

    function test_ExactInputSingle_RevertsWhenMinimumOutTooHigh() public {
        vm.prank(user);
        vm.expectRevert(bytes("Too little received"));
        swap.SwapExactInputSingle(WETH, USDC, FEE_MEDIUM, 1 ether, type(uint256).max);
    }

    // ==============================================================================
    // EXACT OUTPUT SINGLE - Buy exact amount, spend minimum input
    // ==============================================================================

    function test_ExactOutputSingle_WethToUsdc() public {
        uint256 amountOut = 2000e6; // EXACTLY 2000 USDC
        uint256 amountInMax = 5 ether;
        uint256 wethBefore = IERC20(WETH).balanceOf(user);
        uint256 usdcBefore = IERC20(USDC).balanceOf(user);

        vm.prank(user);
        swap.SwapExactOutputSingle(WETH, USDC, FEE_MEDIUM, amountOut, amountInMax);

        uint256 wethSpent = wethBefore - IERC20(WETH).balanceOf(user);
        console2.log("WETH spent for 2000 USDC:", wethSpent);

        // Received exactly the requested output
        assertEq(IERC20(USDC).balanceOf(user) - usdcBefore, amountOut, "USDC received != amountOut");
        // Spent something, but never more than the maximum
        assertGt(wethSpent, 0, "no WETH spent");
        assertLe(wethSpent, amountInMax, "spent more than amountInMaximum");
    }

    function test_ExactOutputSingle_RefundsUnusedInput() public {
        uint256 amountInMax = 5 ether;
        uint256 wethBefore = IERC20(WETH).balanceOf(user);

        vm.prank(user);
        swap.SwapExactOutputSingle(WETH, USDC, FEE_MEDIUM, 2000e6, amountInMax);

        // The max was pulled, but the unused part must have come back
        assertLt(wethBefore - IERC20(WETH).balanceOf(user), amountInMax, "nothing was refunded");
        assertEq(IERC20(WETH).balanceOf(address(swap)), 0, "WETH stuck in contract");
        assertEq(IERC20(WETH).allowance(address(swap), SWAP_ROUTER), 0, "router allowance not cleared");
    }

    function test_ExactOutputSingle_RevertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(UniswapV3Swap.ZeroAmount.selector);
        swap.SwapExactOutputSingle(WETH, USDC, FEE_MEDIUM, 0, 1 ether);
    }

    function test_ExactOutputSingle_RevertsWhenMaximumInTooLow() public {
        vm.prank(user);
        vm.expectRevert();
        swap.SwapExactOutputSingle(WETH, USDC, FEE_MEDIUM, 2000e6, 1 wei);
    }

    // ==============================================================================
    // EXACT INPUT MULTI-HOP - Chain multiple pools together
    // ==============================================================================

    function test_ExactInputMultihop_DaiToWeth() public {
        uint256 amountIn = 3000 ether; // 3000 DAI
        // DAI -> (0.05% pool) -> USDC -> (0.3% pool) -> WETH
        bytes memory path = abi.encodePacked(DAI, FEE_LOW, USDC, FEE_MEDIUM, WETH);

        uint256 daiBefore = IERC20(DAI).balanceOf(user);
        uint256 wethBefore = IERC20(WETH).balanceOf(user);

        vm.prank(user);
        uint256 amountOut = swap.swapExactInputMultihop(path, amountIn, 1);

        console2.log("3000 DAI -> WETH:", amountOut);

        assertGt(amountOut, 0, "no WETH received");
        assertEq(daiBefore - IERC20(DAI).balanceOf(user), amountIn, "DAI spent != amountIn");
        assertEq(IERC20(WETH).balanceOf(user) - wethBefore, amountOut, "WETH received != amountOut");
        // Nothing is left behind in the intermediate token
        assertEq(IERC20(USDC).balanceOf(address(swap)), 0, "USDC stuck in contract");
    }

    function test_ExactInputMultihop_RevertsOnZeroAmount() public {
        bytes memory path = abi.encodePacked(DAI, FEE_LOW, USDC, FEE_MEDIUM, WETH);

        vm.prank(user);
        vm.expectRevert(UniswapV3Swap.ZeroAmount.selector);
        swap.swapExactInputMultihop(path, 0, 0);
    }

    function test_ExactInputMultihop_RevertsWhenMinimumOutTooHigh() public {
        bytes memory path = abi.encodePacked(DAI, FEE_LOW, USDC, FEE_MEDIUM, WETH);

        vm.prank(user);
        vm.expectRevert(bytes("Too little received"));
        swap.swapExactInputMultihop(path, 3000 ether, type(uint256).max);
    }
}
