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

contract FairLaunchHook is BaseHook {
    using CurrencySettler for Currency;

    error CantAddLiquidity();
    error FairLaunchFailed();

    uint160 private constant SQRTPRICEX96 = 4582 << 96;
    int24 private constant START_TICK = 168606;
    uint256 private constant TOTAL_SUPPLY = 420_000_000e18;
    uint256 private constant INITIAL_LIQUIDITY_AMOUNT = 210_000_000e18;
    uint256 private constant CONSTANT_PRICE_DURATION = 1 hours;
    uint256 private constant FAIR_LAUNCH_DURATION = 7 days;

    uint8 public fairLaunchStatus; // 0 - none, 1 - started, 2 - ended, 3 - failed

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

    struct LiquidityData {
        address token;
    }

    function createFairLaunch(string memory name, string memory symbol) external {
        Token token = new Token(name, symbol, 18, TOTAL_SUPPLY);

        PoolKey memory key = PoolKey({
            currency0: CurrencyLibrary.NATIVE,
            currency1: Currency.wrap(address(token)),
            fee: 10000,
            tickSpacing: 200,
            hooks: IHooks(address(this))
        });
        poolManager.initialize(key, SQRTPRICEX96, "");

        poolManager.unlock(abi.encode(address(token)));
    }

    function unlockCallback(bytes calldata data) external override poolManagerOnly returns (bytes memory) {
        address token = abi.decode(data, (address));

        Token(token).approve(address(poolManager), INITIAL_LIQUIDITY_AMOUNT);

        Currency currency1 = Currency.wrap(token);

        // Settle `amountEach` of each currency from the sender
        // i.e. Create a debit of `amountEach` of each currency with the Pool Manager
        currency1.settle(
            poolManager,
            address(this),
            INITIAL_LIQUIDITY_AMOUNT,
            false // `burn` = `false` i.e. we're actually transferring tokens, not burning ERC-6909 Claim Tokens
        );

        currency1.take(poolManager, address(this), INITIAL_LIQUIDITY_AMOUNT, true);

        return "";
    }

    function beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        if (fairLaunchStatus != 2) revert CantAddLiquidity();

        return this.beforeAddLiquidity.selector;
    }

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata)
        external
        override
        poolManagerOnly
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // uint256 status = fairLaunchStatus;

        // // behave like normal pool after fair launch
        // if (status == 2) return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);

        // // revert when fair launch has failed to launch fairly :)
        // if (status == 3) revert FairLaunchFailed();

        // if (block.timestamp < constantPriceEnd) {
        //     // swap without fees keeping the sqrt price same
        // }

        // if (block.timestamp < fairLaunchEnd) {}
    }
}
