// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolManager} from "../../src/PoolManager.sol";
import {PoolKey} from "../../src/types/PoolKey.sol";
import {Currency} from "../../src/types/Currency.sol";
import {BalanceDelta, toBalanceDelta} from "../../src/types/BalanceDelta.sol";
import {SwapParams} from "../../src/types/PoolOperation.sol";
import {BaseHook} from "../../src/libraries/BaseHook.sol";
import {IHooks} from "../../src/interfaces/IHooks.sol";
import {Hooks} from "../../src/libraries/Hooks.sol";

contract MaliciousDeltaHook is BaseHook {
    Currency public currency1;
    address public attacker;

    constructor(PoolManager _manager) BaseHook(_manager) {}

    function setCurrency1(Currency _c) external { currency1 = _c; }
    function setAttacker(address _a) external { attacker = _a; }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function afterSwap(
        address,
        PoolKey calldata,
        SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) external override returns (bytes4, BalanceDelta) {
        // 1e18 - safe, does NOT overflow SafeCast
        BalanceDelta delta = toBalanceDelta(int128(int256(1e18)), int128(0));
        return (IHooks.afterSwap.selector, delta);
    }
}