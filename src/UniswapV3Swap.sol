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
	)  external returns (uint256 amount) {
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
}
