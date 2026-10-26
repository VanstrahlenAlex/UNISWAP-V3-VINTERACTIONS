// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";

/// @title UniswapV3Liquidity — Concentrated Liquidity Management
/// @author Blockchain Accelerator - Jose Cruz
/// @notice Demonstrates how to provide liquidity on Uniswap V3.
///
/// ═══════════════════════════════════════════════════════════════════════
/// CONCENTRATED LIQUIDITY — The Big Innovation in V3
/// ═══════════════════════════════════════════════════════════════════════
///
/// In Uniswap V2, liquidity was spread across the ENTIRE price range (0 to ∞).
/// This was capital-inefficient — most of the liquidity was never used.
///
/// In Uniswap V3, LPs choose a SPECIFIC price range for their liquidity:
///   - tickLower = lower bound of the price range
///   - tickUpper = upper bound of the price range
///
/// Your liquidity is only active (earns fees) when the current price is within
/// your range. Tighter ranges = more fees per dollar, but higher risk of going
/// out of range.
///
/// TICKS:
///   - Ticks represent discrete price points: price = 1.0001^tick
///   - Tick 0 = price 1.0
///   - Tick 23027 ≈ price 10.0
///   - tickLower and tickUpper must be multiples of the pool's tick spacing
///   - Fee 500 (0.05%) → tickSpacing = 10
///   - Fee 3000 (0.3%) → tickSpacing = 60
///   - Fee 10000 (1%) → tickSpacing = 200
///
/// POSITIONS AS NFTs:
///   - Each liquidity position is minted as an ERC-721 NFT
///   - The NFT represents: which pool + which tick range + how much liquidity
///   - You can transfer, sell, or use the NFT as collateral
///
contract UniswapV3Liquidity {


	INonfungiblePositionManager public immutable POSITION_MANAGER;

	error ZeroAmount();

	event PositionMinted(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
	event LiquidityIncreased(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
	event LiquidityDecreased(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
	event FeeCollected(uint256 indexed tokenId, uint256 amount0, uint256 amount1);

	constructor(address _positionManager) {
		POSITION_MANAGER = INonfungiblePositionManager(_positionManager);
	}

	

	
}
