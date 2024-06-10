pragma solidity 0.8.25;

import {FairLaunchHook} from "../src/FairLaunchHook.sol";
import {Test, console} from "forge-std/Test.sol";
import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

contract FairLauncherTest is Test, Deployers {
    FairLaunchHook fairLaunchHook;
    uint160 private constant SQRT_PRICE = 4582 << 96;
    int24 private constant START_TICK = 168606;

    function setUp() public {
        deployFreshManagerAndRouters();
        address hookAddress = address(uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG));
        deployCodeTo("FairLaunchHook.sol", abi.encode(manager), hookAddress);
        fairLaunchHook = FairLaunchHook(fairLaunchHook);
    }

    function testStartTick() public {
        assertEq(TickMath.getTickAtSqrtPrice(SQRT_PRICE), START_TICK);
    }
}
