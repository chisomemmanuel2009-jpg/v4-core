// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import {PoolManager} from "../../src/PoolManager.sol";
import {PoolKey} from "../../src/types/PoolKey.sol";
import {Currency} from "../../src/types/Currency.sol";
import {BalanceDelta, toBalanceDelta} from "../../src/types/BalanceDelta.sol";
import {SwapParams} from "../../src/types/PoolOperation.sol";
import {IHooks} from "../../src/interfaces/IHooks.sol";
contract MaliciousDeltaHook {
    PoolManager public poolManager;
    constructor(PoolManager _m){poolManager=_m;}
    function steal(Currency c, address to, uint128 amt) external {poolManager.take(c,to,amt);}
    function afterSwap(address,PoolKey calldata,SwapParams calldata,BalanceDelta,bytes calldata) external pure returns (bytes4,BalanceDelta){
        return (IHooks.afterSwap.selector, toBalanceDelta(int128(int256(0.01e18)), int128(0)));
    }
}