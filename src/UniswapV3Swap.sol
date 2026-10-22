// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/// @title UniswapV3Swap — Swap Examples using Uniswap V3 Router
/// @author Blockchain Accelerator - Jose Cruz
/// @notice Demonstrates single-hop and multi-hop swaps on Uniswap V3.
///
/// ═══════════════════════════════════════════════════════════════════════
/// HOW UNISWAP V3 SWAPS WORK
/// ═══════════════════════════════════════════════════════════════════════
///
/// Uniswap V3 offers two main swap modes:
///
///   1. Exact Input  — "I want to sell EXACTLY 1 WETH. How much USDC will I get?"
///   2. Exact Output — "I want to buy EXACTLY 2000 USDC. How much WETH will it cost?"
///
/// Both modes can be single-hop (one pool) or multi-hop (multiple pools in sequence).
///
/// FEE TIERS:
///   - 500   (0.05%) — Stable pairs (USDC/DAI)
///   - 3000  (0.30%) — Standard pairs (WETH/USDC)
///   - 10000 (1.00%) — Exotic pairs
///
/// KEY PARAMETER: sqrtPriceLimitX96
///   - Controls how far the price can move during a swap
///   - Set to 0 to accept ANY price (most common for simple swaps)
///   - In production, set a limit to protect against sandwich attacks
///

contract UniswapV3Swap {
	ISwapRouter public immutable ROUTER; 

	error ZeroAmount();

	event SwapExecuted(
		address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
	); 

	constructor(address _router) {
		ROUTER = ISwapRouter(_router);
	}

	//==============================================================================
	// EXACT INPUT SINGLE - Sell exact amount, get maximum output.
	//==============================================================================

	function SwapExactInputSingle(
		address tokenIn,
		address tokenOut,
		uint24 fee,
		uint256 amountIn,
		uint256 amountOutMinimum
	)  external returns (uint256 amountOut) {
		if(amountIn == 0) revert ZeroAmount();

		IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

		IERC20(tokenIn).approve(address(ROUTER), amountIn);

		ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
			tokenIn: tokenIn,
			tokenOut : tokenOut,
			fee : fee,
			recipient : msg.sender,
			deadline : block.timestamp,
			amountIn : amountIn,
			amountOutMinimum : amountOutMinimum,
			sqrtPriceLimitX96: 0
		});

		amountOut = ROUTER.exactInputSingle(params);
		
		emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut);
		
		return amountOut;
	}


	function SwapExactOutputSingle(
		address tokenIn,
		address tokenOut,
		uint24 fee,
		uint256 amountOut,
		uint256 amountInMaximum
	)  external returns (uint256 amountIn) {
		if(amountOut == 0) revert ZeroAmount();

		IERC20(tokenIn).transferFrom(msg.sender, address(this), amountInMaximum);

		IERC20(tokenIn).approve(address(ROUTER), amountInMaximum);

		ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
			tokenIn: tokenIn,
			tokenOut : tokenOut,
			fee : fee,
			recipient : msg.sender,
			deadline : block.timestamp,
			amountOut : amountOut,
			amountInMaximum : amountInMaximum,
			sqrtPriceLimitX96: 0
		});

		amountIn = ROUTER.exactOutputSingle(params);

		if(amountIn < amountInMaximum) {
			IERC20(tokenIn).approve(address(ROUTER), 0);
			IERC20(tokenIn).transfer(msg.sender, amountInMaximum - amountIn);
		}

		emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut);

		return amountIn;
	}

	// ==============================================================================
	// EXACT INPUT MULTI-HOP — Chain multiple pools together
	// ==============================================================================

	/// @notice Multi-hop swap: chain multiple pools for better routing
	/// @dev The path is ABI-encoded as: abi.encodePacked(tokenA, fee1, tokenB, fee2, tokenC)
	///
	/// Example: DAI → (0.05% pool) → USDC → (0.3% pool) → WETH
	///   path = abi.encodePacked(DAI, uint24(500), USDC, uint24(3000), WETH)
	///
	/// WHY MULTI-HOP?
	///   - Sometimes there's no direct pool between two tokens
	///   - Sometimes routing through an intermediate token gives a better price
	///   - Example: DAI → WETH might be cheaper as DAI → USDC → WETH
	///

	function swapExactInputMultihop(bytes calldata path, uint256 amountIn, uint256 amountOutMinimum) external returns(uint256 amountOut) {
		if(amountIn == 0) revert ZeroAmount();

		// path = tokenIn (20 bytes) | fee (3 bytes) | ... | tokenOut (20 bytes)
		address tokenIn;
		address tokenOut;
		assembly {
			tokenIn := shr(96, calldataload(path.offset))
			tokenOut := shr(96, calldataload(add(path.offset, sub(path.length, 20))))
		}

		IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
		IERC20(tokenIn).approve(address(ROUTER), amountIn);

		ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
			path: path,
			recipient : msg.sender,
			deadline : block.timestamp,
			amountIn : amountIn,
			amountOutMinimum : amountOutMinimum
		});

		amountOut = ROUTER.exactInput(params);
		emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut);
		return amountOut;
		
	}
}
