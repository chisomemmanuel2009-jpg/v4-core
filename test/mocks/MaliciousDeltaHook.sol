// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import {IHooks} from "../../src/interfaces/IHooks.sol";
import {PoolKey} from "../../src/types/PoolKey.sol";
import {BalanceDelta} from "../../src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "../../src/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "../../src/types/PoolOperation.sol";
import {PoolManager} from "../../src/PoolManager.sol";
import {Currency} from "../../src/types/Currency.sol";

contract MaliciousDeltaHook is IHooks {
    PoolManager public poolManager;
    Currency public stealC;
    address public stealTo;
    constructor(PoolManager _m){ poolManager=_m; }
    function setSteal(Currency c, address to) external { stealC=c; stealTo=to; }
    function beforeInitialize(address, PoolKey calldata, uint160) external pure returns (bytes4){ return IHooks.beforeInitialize.selector; }
    function afterInitialize(address, PoolKey calldata, uint160, int24) external pure returns (bytes4){ return IHooks.afterInitialize.selector; }
    function beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata) external pure returns (bytes4){ return IHooks.beforeAddLiquidity.selector; }
    function afterAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, BalanceDelta, BalanceDelta, bytes calldata) external pure returns (bytes4, BalanceDelta){ return (IHooks.afterAddLiquidity.selector, BalanceDelta.wrap(0)); }
    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata) external pure returns (bytes4){ return IHooks.beforeRemoveLiquidity.selector; }
    function afterRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, BalanceDelta, BalanceDelta, bytes calldata) external pure returns (bytes4, BalanceDelta){ return (IHooks.afterRemoveLiquidity.selector, BalanceDelta.wrap(0)); }
    function beforeSwap(address, PoolKey calldata, SwapParams calldata, bytes calldata) external pure returns (bytes4, BeforeSwapDelta, uint24){ return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0); }
    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata) external pure returns (bytes4, int128){
        return (IHooks.afterSwap.selector, -10000000000000000);
    }
    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) external pure returns (bytes4){ return IHooks.beforeDonate.selector; }
    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) external pure returns (bytes4){ return IHooks.afterDonate.selector; }
    function steal(Currency c, address to, uint256 a) external { poolManager.take(c,to,a); }
}