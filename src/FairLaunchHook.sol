// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BeforeSwapDelta, toBeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {Token} from "./Token.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {CurrencySettler} from "v4-core-test/utils/CurrencySettler.sol";
import {LiquidityAmounts} from "v4-periphery/libraries/LiquidityAmounts.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {console} from "forge-std/Test.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";

contract FairLaunchHook is BaseHook {
    using CurrencySettler for Currency;

    error CantAddLiquidity();
    error FairLaunchFailed();

    uint160 private constant SQRTPRICEX96_LOWER = 362910073449872328385539408603818;
    uint160 private constant SQRTPRICEX96_UPPER = 364000383803451422962285634103846;
    int24 private constant START_TICK_LOWER = 168600;
    int24 private constant START_TICK_UPPER = 168660;
    uint256 private constant TOTAL_SUPPLY = 420_000_000e18;
    uint256 private constant INITIAL_LIQUIDITY_AMOUNT = 15259796509662827620281713;
    uint256 private constant INITIAL_TOKEN_AMOUNT = 209999999999999999999999991;
    uint256 private constant CONSTANT_PRICE_DURATION = 1 hours;
    uint256 private constant FAIR_LAUNCH_DURATION = 7 days;

    uint8 public fairLaunchStatus; // 0 - none, 1 - started, 2 - ended, 3 - failed

    struct FairLaunchInfo {
        uint8 status;
        uint40 constantEnd;
        uint40 fairLaunchEnd;
    }

    mapping(address => FairLaunchInfo) public fairLaunchesInfo;

    constructor(IPoolManager poolManager) BaseHook(poolManager) {
        fairLaunchStatus = 1;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true, // Don't allow adding liquidity normally
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true, // Override how swaps are done
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false, // Allow beforeSwap to return a custom delta
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function createFairLaunch(string memory name, string memory symbol) external {
        Token token = new Token(name, symbol, 18, TOTAL_SUPPLY);

        PoolKey memory key = PoolKey({
            currency0: CurrencyLibrary.NATIVE,
            currency1: Currency.wrap(address(token)),
            fee: 10000,
            tickSpacing: 60,
            hooks: IHooks(address(this))
        });
        poolManager.initialize(key, SQRTPRICEX96_UPPER, "");

        poolManager.unlock(abi.encode(address(token)));

        fairLaunchesInfo[address(token)] = FairLaunchInfo({
            status: 1,
            constantEnd: uint40(block.timestamp + CONSTANT_PRICE_DURATION),
            fairLaunchEnd: uint40(block.timestamp + FAIR_LAUNCH_DURATION)
        });
    }

    function unlockCallback(bytes calldata data) external override poolManagerOnly returns (bytes memory) {
        address token = abi.decode(data, (address));

        Currency currency = Currency.wrap(address(token));

        PoolKey memory key = PoolKey({
            currency0: CurrencyLibrary.NATIVE,
            currency1: currency,
            fee: 10000,
            tickSpacing: 60,
            hooks: IHooks(address(this))
        });

        IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
            tickLower: START_TICK_LOWER,
            tickUpper: START_TICK_UPPER,
            liquidityDelta: SafeCast.toInt256(INITIAL_LIQUIDITY_AMOUNT),
            salt: bytes32(0)
        });

        (BalanceDelta callerDelta,) = poolManager.modifyLiquidity(key, params, "");

        CurrencySettler.settle(currency, poolManager, address(this), INITIAL_TOKEN_AMOUNT, false);

        return "";
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata pool,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external view override returns (bytes4) {
        if (fairLaunchesInfo[Currency.unwrap(pool.currency1)].status != 2) revert CantAddLiquidity();

        return this.beforeAddLiquidity.selector;
    }

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        poolManagerOnly
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        FairLaunchInfo storage fairLaunchInfo = fairLaunchesInfo[Currency.unwrap(key.currency1)];
        uint256 status = fairLaunchInfo.status;

        // behave like normal pool after fair launch
        if (status == 2) return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);

        // revert when fair launch has failed -> sell all tokens for the same price using NoOp hook
        // TODO: currently it behaves like a normal pool and users must compete to achieve best price
        if (status == 3) return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);

        if (block.timestamp > fairLaunchInfo.fairLaunchEnd) {
            // TODO: at this point all trading must be frozen and NoOp hook that ensures all
            // users get same execution price must be enforced
            fairLaunchInfo.status = 3;
            return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        if (block.timestamp > fairLaunchInfo.constantEnd) {
            // remove liquidity
            IPoolManager.ModifyLiquidityParams memory modifyLiqParams = IPoolManager.ModifyLiquidityParams({
                tickLower: START_TICK_LOWER,
                tickUpper: START_TICK_UPPER,
                liquidityDelta: -SafeCast.toInt256(INITIAL_LIQUIDITY_AMOUNT),
                salt: bytes32(0)
            });
            (BalanceDelta callerDelta,) = poolManager.modifyLiquidity(key, modifyLiqParams, "");
            return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }
    }
}
