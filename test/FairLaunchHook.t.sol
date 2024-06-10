pragma solidity 0.8.25;

import {FairLaunchHook} from "../src/FairLaunchHook.sol";
import {Test, console} from "forge-std/Test.sol";
import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";

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

    function testStartTick() public pure {
        assertEq(TickMath.getTickAtSqrtPrice(SQRTPRICEX96_LOWER), START_TICK_LOWER);
        assertEq(TickMath.getTickAtSqrtPrice(SQRTPRICEX96_UPPER), START_TICK_UPPER);
    }

    function testCreateFairLaunch() public {
        fairLaunchHook.createFairLaunch("FUN", "FUN");
        assertTrue(_addressFrom(address(fairLaunchHook), 0).code.length > 0);
    }

    function testConstantPrice() public {
        fairLaunchHook.createFairLaunch("FUN", "FUN");
        address token = _addressFrom(address(fairLaunchHook), 0);

        deal(address(this), 10 ether);

        PoolKey memory key = PoolKey({
            currency0: CurrencyLibrary.NATIVE,
            currency1: Currency.wrap(address(token)),
            fee: 10000,
            tickSpacing: 60,
            hooks: IHooks(address(this))
        });
        swap(key, true, -0.1 ether, "");
    }

    function _addressFrom(address _origin, uint256 _nonce) public pure returns (address) {
        bytes memory data;
        if (_nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, bytes1(0x80));
        } else if (_nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, uint8(_nonce));
        } else if (_nonce <= 0xff) {
            data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), _origin, bytes1(0x81), uint8(_nonce));
        } else if (_nonce <= 0xffff) {
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), _origin, bytes1(0x82), uint16(_nonce));
        } else if (_nonce <= 0xffffff) {
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), _origin, bytes1(0x83), uint24(_nonce));
        } else {
            data = abi.encodePacked(bytes1(0xda), bytes1(0x94), _origin, bytes1(0x84), uint32(_nonce));
        }
        return address(uint160(uint256(keccak256(data))));
    }
}
