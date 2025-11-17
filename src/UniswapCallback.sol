//SPDX-License-Identifier：MIT
pragma solidity ^0.8.30;

import {IUniswapV3SwapCallback} from "v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract UniswapCallback is IUniswapV3SwapCallback{
    using SafeERC20 for IERC20;

    address public immutable token0;
    address public immutable token1;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    // 实现回调接口：由 Uniswap Pool 在 swap 过程中调用
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        // Pool 地址就是 msg.sender
        address pool = msg.sender;

        // Token 0 支付逻辑
        if (amount0Delta > 0) {
            // Pool 需要从本合约（即 msg.sender/Pool 的地址）接收 amount0Delta 数量的 Token 0
            // 因此，本合约需要将 Token 0 支付给 Pool
            IERC20(token0).safeTransfer(pool, uint256(amount0Delta));
        }

        // Token 1 支付逻辑
        if (amount1Delta > 0) {
            // 同理，如果 Pool 需要 Token 1，本合约需要支付
            IERC20(token1).safeTransfer(pool, uint256(amount1Delta));
        }
        
    }
}