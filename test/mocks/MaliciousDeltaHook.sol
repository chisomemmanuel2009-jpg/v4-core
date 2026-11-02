// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import {BaseHook} from "../../src/libraries/BaseHook.sol";
import {Hooks} from "../../src/libraries/Hooks.sol";
import {PoolKey} from "../../src/types/PoolKey.sol";
import {BalanceDelta} from "../../src/types/BalanceDelta.sol";
import {PoolManager} from "../../src/PoolManager.sol";
import {Currency} from "../../src/types/Currency.sol";
contract MaliciousDeltaHook is BaseHook {
    constructor(PoolManager _m) BaseHook(_m) {}
    function getHookPermissions() public pure override returns (Hooks.Permissions memory p){
        p.afterSwap = true;
        p.afterSwapReturnDelta = true;
    }
    function _afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata) internal override returns (bytes4, int128){
        return (this.afterSwap.selector, 0);
    }
    function steal(Currency c, address to, uint256 a) external {
        poolManager.take(c, to, a);
    }
}