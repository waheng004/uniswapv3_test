// script/Deploy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {UniswapCallback} from "../src/UniswapCallback.sol";
import {console} from "forge-std/console.sol";

contract DeployCallback is Script {
    // Sepolia WETH 和 USDC 地址 (与 constants/index.ts 保持一致)
    address constant WETH_SEPOLIA = 0xFFF9976782D46CC05630d1F6eb9BF98BF9FF1CAA;
    address constant USDC_SEPOLIA = 0x779877a7b0d9E8603169DdBd7836E478F462f65e;

    function run() public returns (address callbackAddress) {
        // 1. 从环境变量获取私钥
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        // 2. 开始部署
        vm.startBroadcast(privateKey);

        // 部署 UniswapCallback 合约，传入 Token 0 和 Token 1 地址
        UniswapCallback callback = new UniswapCallback(WETH_SEPOLIA, USDC_SEPOLIA);

        vm.stopBroadcast();

        callbackAddress = address(callback);
        console.log("UniswapCallback deployed to: %s", callbackAddress);
    }
}