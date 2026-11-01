// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta, toBalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
contract MaliciousDeltaHook is BaseHook {
    constructor(IPoolManager _pm) BaseHook(_pm) {}
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions(false,false,false,false,false,false,false,true,false,false,false,true,false,false);
    }
    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata) external override returns (bytes4, BalanceDelta) {
        return (this.afterSwap.selector, toBalanceDelta(0, int128(10e18)));
    }
}