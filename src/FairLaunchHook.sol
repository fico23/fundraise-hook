// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Token} from "./Token.sol";

import {console} from "forge-std/Test.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {CurrencySettler} from "v4-core-test/utils/CurrencySettler.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {FixedPoint96} from "v4-core/libraries/FixedPoint96.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {Position} from "v4-core/libraries/Position.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BaseHook} from "v4-periphery/BaseHook.sol";
import {LiquidityAmounts} from "v4-periphery/libraries/LiquidityAmounts.sol";

contract FairLaunchHook is BaseHook {
    using CurrencySettler for Currency;

    error CantAddLiquidity();
    error FairLaunchFailed();

    uint160 private constant SQRTPRICEX96_END = 18016810018735514800466276983207;
    uint160 private constant SQRTPRICEX96_LOWER = 362910073449872328385539408603818;
    uint160 private constant SQRTPRICEX96_UPPER = 364000383803451422962285634103846;
    uint160 private constant SQRTPRICEX96_UPPER_NEXT = 365093969835370942477283908147566;
    uint160 private constant SQRTPRICEX96_MIN = 4306310044;
    uint160 private constant SQRTPRICEX96_MAX = 1457652066949847389969617340386294118487833376468;
    int24 private constant END_TICK = 108540;
    int24 private constant START_TICK_LOWER = 168600;
    int24 private constant START_TICK_UPPER = 168660;
    int24 private constant START_TICK_UPPER_NEXT = 168720;
    int24 private constant MIN_TICK = -887220;
    int24 private constant MAX_TICK = 887220;
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
            afterSwap: true,
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

        poolManager.modifyLiquidity(key, params, "");

        CurrencySettler.settle(currency, poolManager, address(this), INITIAL_TOKEN_AMOUNT, false);

        return "";
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        revert CantAddLiquidity();
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
            (BalanceDelta balanceDelta,) = poolManager.modifyLiquidity(key, modifyLiqParams, "");

            // if any ETH is earned add ETH as narrow one sided liquidity
            if (balanceDelta.amount0() > 0) {
                modifyLiqParams = IPoolManager.ModifyLiquidityParams({
                    tickLower: START_TICK_UPPER,
                    tickUpper: START_TICK_UPPER_NEXT,
                    liquidityDelta: SafeCast.toInt256(
                        LiquidityAmounts.getLiquidityForAmount0(
                            SQRTPRICEX96_UPPER, SQRTPRICEX96_UPPER_NEXT, uint256(int256(balanceDelta.amount0()))
                        )
                    ),
                    salt: bytes32(0)
                });
                (BalanceDelta balanceDeltaEth,) = poolManager.modifyLiquidity(key, modifyLiqParams, "");
                balanceDelta = balanceDelta + balanceDeltaEth;
            }

            // add all remaining tokens as a wide one sided liquidity
            modifyLiqParams = IPoolManager.ModifyLiquidityParams({
                tickLower: END_TICK,
                tickUpper: START_TICK_LOWER,
                liquidityDelta: SafeCast.toInt256(
                    LiquidityAmounts.getLiquidityForAmount1(
                        SQRTPRICEX96_END, SQRTPRICEX96_LOWER, uint256(int256(balanceDelta.amount1()))
                    )
                ),
                salt: bytes32(0)
            });
            (BalanceDelta balanceDeltaToken,) = poolManager.modifyLiquidity(key, modifyLiqParams, "");
            balanceDelta = balanceDelta + balanceDeltaToken;

            // handle dust
            if (balanceDelta.amount0() > 0) {
                poolManager.take(CurrencyLibrary.NATIVE, address(this), uint256(int256(balanceDelta.amount0())));
            }
            if (balanceDelta.amount1() > 0) {
                poolManager.take(key.currency1, address(this), uint256(int256(balanceDelta.amount1())));
            }

            return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        override
        poolManagerOnly
        returns (bytes4, int128)
    {
        FairLaunchInfo storage fairLaunchInfo = fairLaunchesInfo[Currency.unwrap(key.currency1)];
        uint256 status = fairLaunchInfo.status;
        if (status != 1) return (this.afterSwap.selector, 0);

        (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(poolManager, PoolIdLibrary.toId(key));
        if (block.timestamp < fairLaunchInfo.constantEnd) {
            if (sqrtPriceX96 <= SQRTPRICEX96_LOWER) {
                // success
                fairLaunchInfo.status = 3;

                IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
                    tickLower: START_TICK_LOWER,
                    tickUpper: START_TICK_UPPER,
                    liquidityDelta: -SafeCast.toInt256(INITIAL_LIQUIDITY_AMOUNT),
                    salt: bytes32(0)
                });

                (BalanceDelta balanceDelta,) = poolManager.modifyLiquidity(key, params, "");
                _addNewPool(key, balanceDelta);
            }
        } else if (sqrtPriceX96 <= SQRTPRICEX96_END) {
            // success
            fairLaunchInfo.status = 3;

            BalanceDelta balanceDelta = _removeExistingLiquidity(key, START_TICK_UPPER, START_TICK_UPPER_NEXT);
            balanceDelta = balanceDelta + _removeExistingLiquidity(key, END_TICK, START_TICK_LOWER);

            _addNewPool(key, balanceDelta);
        }

        return (this.afterSwap.selector, 0);
    }

    function _removeExistingLiquidity(PoolKey calldata key, int24 tickLower, int24 tickUpper)
        internal
        returns (BalanceDelta balanceDelta)
    {
        Position.Info memory position = StateLibrary.getPosition(
            poolManager, PoolIdLibrary.toId(key), address(this), tickLower, tickUpper, bytes32(0)
        );

        if (position.liquidity > 0) {
            IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: -SafeCast.toInt256(position.liquidity),
                salt: bytes32(0)
            });

            (balanceDelta,) = poolManager.modifyLiquidity(key, params, "");
        }
    }

    function _addNewPool(PoolKey calldata key, BalanceDelta balanceDelta) internal {
        PoolKey memory newKey = PoolKey({
            currency0: CurrencyLibrary.NATIVE,
            currency1: key.currency1,
            fee: 10000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        uint256 tokensRemaining = Token(Currency.unwrap(key.currency1)).balanceOf(address(this));
        uint160 newPrice = _calculateNewSqrtPrice(balanceDelta, tokensRemaining);

        poolManager.initialize(newKey, newPrice, "");

        IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
            tickLower: MIN_TICK,
            tickUpper: MAX_TICK,
            liquidityDelta: SafeCast.toInt256(
                uint256(
                    LiquidityAmounts.getLiquidityForAmounts(
                        newPrice,
                        SQRTPRICEX96_MIN,
                        SQRTPRICEX96_MAX,
                        uint256(int256(balanceDelta.amount0())),
                        tokensRemaining
                    )
                )
            ),
            salt: bytes32(0)
        });
        poolManager.modifyLiquidity(newKey, params, "");

        CurrencySettler.settle(key.currency1, poolManager, address(this), tokensRemaining, false);
        _donateDust(newKey);
    }

    function _calculateNewSqrtPrice(BalanceDelta balanceDelta, uint256 tokensRemaining)
        internal
        pure
        returns (uint160)
    {
        return uint160(
            FixedPointMathLib.sqrt(
                FullMath.mulDiv(uint128(tokensRemaining), FixedPoint96.Q96, uint128(balanceDelta.amount0()))
            ) * FixedPointMathLib.sqrt(FixedPoint96.Q96)
        );
    }

    function _donateDust(PoolKey memory key) internal {
        int256 amount0 = TransientStateLibrary.currencyDelta(poolManager, address(this), key.currency0);
        int256 amount1 = TransientStateLibrary.currencyDelta(poolManager, address(this), key.currency1);
        if (amount0 > 0 || amount1 > 0) {
            poolManager.donate(key, uint256(amount0), uint256(amount1), "");
        }
    }
}
