// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import {BaseHook} from "@uniswap/v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "../../src/libraries/Hooks.sol";
import {PoolKey} from "../../src/types/PoolKey.sol";
import {BalanceDelta, toBalanceDelta} from "../../src/types/BalanceDelta.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "../../src/types/BeforeSwapDelta.sol";
import {IPoolManager} from "../../src/interfaces/IPoolManager.sol";
import {SwapParams} from "../../src/types/PoolOperation.sol";

contract MaliciousDeltaHook is BaseHook {
    constructor(IPoolManager _pm) BaseHook(_pm) {}
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false, afterInitialize: false,
            beforeAddLiquidity: false, afterAddLiquidity: false,
            beforeRemoveLiquidity: false, afterRemoveLiquidity: false,
            beforeSwap: false, afterSwap: true,
            beforeDonate: false, afterDonate: false,
            beforeSwapReturnDelta: false, afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false, afterRemoveLiquidityReturnDelta: false
        });
    }
    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata) external override returns (bytes4, BalanceDelta) {
        return (this.afterSwap.selector, toBalanceDelta(0, int128(10e18)));
    }
}