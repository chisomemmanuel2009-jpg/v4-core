// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import {IHooks} from "../../src/interfaces/IHooks.sol";
import {Hooks} from "../../src/libraries/Hooks.sol";
import {PoolKey} from "../../src/types/PoolKey.sol";
import {BalanceDelta, toBalanceDelta} from "../../src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "../../src/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "../../src/types/PoolOperation.sol";
import {IPoolManager} from "../../src/interfaces/IPoolManager.sol";
import {Currency} from "../../src/types/Currency.sol";

contract MaliciousDeltaHook is IHooks {
    IPoolManager public poolManager;
    Currency public currency1;
    address public attacker;
    constructor(address _manager){poolManager=IPoolManager(_manager);}
    function setCurrency1(Currency _c) external {currency1=_c;}
    function setAttacker(address _a) external {attacker=_a;}
    function drain(uint256 amount) external {poolManager.take(currency1, attacker, amount);}
    function getHookPermissions() public pure returns (Hooks.Permissions memory){
        return Hooks.Permissions({beforeInitialize:false,afterInitialize:false,beforeAddLiquidity:false,afterAddLiquidity:false,beforeRemoveLiquidity:false,afterRemoveLiquidity:false,beforeSwap:false,afterSwap:true,beforeDonate:false,afterDonate:false,beforeSwapReturnDelta:false,afterSwapReturnDelta:true,afterAddLiquidityReturnDelta:false,afterRemoveLiquidityReturnDelta:false});
    }
    function beforeInitialize(address,PoolKey calldata,uint160) external pure returns (bytes4){return IHooks.beforeInitialize.selector;}
    function afterInitialize(address,PoolKey calldata,uint160,int24) external pure returns (bytes4){return IHooks.afterInitialize.selector;}
    function beforeAddLiquidity(address,PoolKey calldata,ModifyLiquidityParams calldata,bytes calldata) external pure returns (bytes4){return IHooks.beforeAddLiquidity.selector;}
    function afterAddLiquidity(address,PoolKey calldata,ModifyLiquidityParams calldata,BalanceDelta,BalanceDelta,bytes calldata) external pure returns (bytes4,BalanceDelta){return (IHooks.afterAddLiquidity.selector,toBalanceDelta(0,0));}
    function beforeRemoveLiquidity(address,PoolKey calldata,ModifyLiquidityParams calldata,bytes calldata) external pure returns (bytes4){return IHooks.beforeRemoveLiquidity.selector;}
    function afterRemoveLiquidity(address,PoolKey calldata,ModifyLiquidityParams calldata,BalanceDelta,BalanceDelta,bytes calldata) external pure returns (bytes4,BalanceDelta){return (IHooks.afterRemoveLiquidity.selector,toBalanceDelta(0,0));}
    function beforeSwap(address,PoolKey calldata,SwapParams calldata,bytes calldata) external pure returns (bytes4,BeforeSwapDelta,uint24){return (IHooks.beforeSwap.selector,BeforeSwapDelta.wrap(0),0);}
    function afterSwap(address,PoolKey calldata,SwapParams calldata,BalanceDelta,bytes calldata) external pure returns (bytes4,int128){return (IHooks.afterSwap.selector,int128(10e18));}
    function beforeDonate(address,PoolKey calldata,uint256,uint256,bytes calldata) external pure returns (bytes4){return IHooks.beforeDonate.selector;}
    function afterDonate(address,PoolKey calldata,uint256,uint256,bytes calldata) external pure returns (bytes4){return IHooks.afterDonate.selector;}
}