// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol"; // 用于打印调试信息
import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3PoolActions} from "v3-core/contracts/interfaces/pool/IUniswapV3PoolActions.sol";
import {IUniswapV3SwapCallback} from "v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
contract UniswapV3SwapTest is Test, IUniswapV3SwapCallback {
    using SafeERC20 for IERC20;

    // --- 主网常量 ---
    // DAI (Token 0): 18位小数 - 主网地址
    address constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    // WETH (Token 1): 18位小数 - 主网地址
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // DAI/WETH 0.3% 池地址 (主网真实池子)
    address constant V3_POOL_ADDRESS = 0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8;

    // --- 变量 ---
    IUniswapV3Pool pool;

    // 实现回调接口
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata
    ) external override {
        // 如果amount0Delta > 0，我们需要支付token0
        if (amount0Delta > 0) {
            IERC20(DAI_ADDRESS).safeTransfer(msg.sender, uint256(amount0Delta));
        }

        // 如果amount1Delta > 0，我们需要支付token1
        if (amount1Delta > 0) {
            IERC20(WETH_ADDRESS).safeTransfer(msg.sender, uint256(amount1Delta));
        }
    }
    
    // 您的 Sepolia 钱包地址 (替换为您自己的地址)
    // 注意：Foundry 仍然会使用 vm.deal 分配资产，以确保测试环境清洁
    address payable user = payable(0x74d2D4688d00e08f2426E94c395168aC0a4A5b95); 
    
    // ----------------------------------------------------
    // 2. 环境设置 (setUp)
    // ----------------------------------------------------

    function setUp() public {
        // 1. 设置主网分叉 (使用公共RPC，完全免费)
        vm.createSelectFork("https://eth.llamarpc.com");

        pool = IUniswapV3Pool(V3_POOL_ADDRESS);

        // 2. 资助测试合约 (使用 vm.deal 作弊码)
        // 分配 5000 DAI (18位小数)
        deal(DAI_ADDRESS, address(this), 5000 ether);
        // 分配 10 WETH (18位小数)
        deal(WETH_ADDRESS, address(this), 10 ether);
    }
    
    // ----------------------------------------------------
    // 3. 测试逻辑 (testSwap)
    // ----------------------------------------------------

    function testSwapDAIForWETH() public {
        // 卖出 1000 DAI (18位小数)
        uint256 amountIn = 1000 ether;

        // --- 记录初始状态 ---
        uint256 balanceDaiBefore = IERC20(DAI_ADDRESS).balanceOf(address(this));
        uint256 balanceWethBefore = IERC20(WETH_ADDRESS).balanceOf(address(this));

        // --- 交易参数确定 ---
        // V3 池: DAI (Token 0) -> WETH (Token 1)
        // zeroForOne = true: 卖出 Token 0 换取 Token 1 (即卖出 DAI 换取 WETH)
        bool zeroForOne = true;

        // 获取当前池子价格
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

        // 设置价格限制：对于zeroForOne=true，价格限制应该小于当前价格
        // 使用当前价格的90%作为最小价格限制
        uint160 sqrtPriceLimitX96 = uint160((uint256(sqrtPriceX96) * 90) / 100);

        (int256 amount0Delta, int256 amount1Delta) = IUniswapV3PoolActions(address(pool)).swap(
            address(this),         // 接收代币的地址
            zeroForOne,            // true: 卖出 Token 0 (DAI)
            // casting to 'int256' is safe because amountIn is always positive
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(amountIn),      // 卖出数量
            sqrtPriceLimitX96,     // 价格限制
            ""                     // data (为空)
        );

        // --- 验证结果 ---

        // amount0Delta 是负数，表示 Token 0 (DAI) 流入了池子
        // amount1Delta 是正数，表示 Token 1 (WETH) 流出了池子（用户获得）

        // 1. 验证用户 DAI 余额减少：
        // casting to 'uint256' is safe because amount0Delta is negative for token0 input
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 amountInActual = uint256(-amount0Delta); // 实际流入池子的 DAI 数量 (含费用)
        uint256 balanceDaiAfter = IERC20(DAI_ADDRESS).balanceOf(address(this));

        // 用户的余额应该减少约等于 amountIn
        assertApproxEqAbs(balanceDaiBefore - balanceDaiAfter, amountIn, 1 ether); // 1 ether 是允许的误差（取决于DAI的小数位）

        // 2. 验证用户 WETH 余额增加：
        // casting to 'uint256' is safe because amount1Delta is positive for token1 output
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 amountOut = uint256(-amount1Delta); // 用户获得的 WETH 数量
        uint256 balanceWethAfter = IERC20(WETH_ADDRESS).balanceOf(address(this));

        assertEq(balanceWethAfter, balanceWethBefore + amountOut, "WETH output incorrect");

        // 打印结果以调试
        console.log("DAI Sold (Actual):", amountInActual);
        console.log("WETH Received:", amountOut);
    }
}