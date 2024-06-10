pragma solidity 0.8.25;

import {FairLaunchHook} from "../src/FairLaunchHook.sol";
import {Test, console} from "forge-std/Test.sol";
import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

contract FairLauncherTest is Test, Deployers {
    FairLaunchHook fairLaunchHook;
    uint160 private constant SQRTPRICEX96_LOWER = 362910073449872328385539408603818;
    uint160 private constant SQRTPRICEX96_UPPER = 364000383803451422962285634103846;
    int24 private constant START_TICK_LOWER = 168600;
    int24 private constant START_TICK_UPPER = 168660;

    function setUp() public {
        deployFreshManagerAndRouters();
        address hookAddress = address(uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG));
        deployCodeTo("FairLaunchHook.sol", abi.encode(manager), hookAddress);
        fairLaunchHook = FairLaunchHook(hookAddress);
    }

    function testStartTick() public {
        assertEq(TickMath.getTickAtSqrtPrice(SQRTPRICEX96_LOWER), START_TICK_LOWER);
        assertEq(TickMath.getTickAtSqrtPrice(SQRTPRICEX96_UPPER), START_TICK_UPPER);
    }

    function testCreateFairLaunch() public {
        fairLaunchHook.createFairLaunch("FUN", "FUN");
    }
}
