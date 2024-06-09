pragma solidity 0.8.25;

import {FairLaunchHook} from "./FairLaunchHook.sol";
import {Token} from "./Token.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

contract FairLauncher {
    IPoolManager public immutable poolManager;
    uint160 private immutable SQRTPRICEX96;
    uint256 private constant TOTAL_SUPPLY = 420_000_000e18;
    uint256 private constant CONSTANT_PRICE_DURATION = 1 hours;
    uint256 private constant FAIR_LAUNCH_DURATION = 7 days;

    constructor(IPoolManager _poolManager, uint160 sqrtPriceX96) {
        poolManager = _poolManager;
        SQRTPRICEX96 = sqrtPriceX96;
    }

    struct LiquidityData {
        Currency currency1;
        uint256 amountToken;
        int24 tickLower;
        int24 tickUpper;
    }

    function createFairLaunch(string memory name, string memory symbol) external {
        Token token = new Token(name, symbol, 18, TOTAL_SUPPLY);

        FairLaunchHook hook = new FairLaunchHook();

        PoolKey memory key = PoolKey({
            currency0: CurrencyLibrary.NATIVE,
            currency1: Currency.wrap(address(token)),
            fee: 10000,
            tickSpacing: 200,
            hooks: IHooks(hook)
        });
        poolManager.initialize(key, SQRTPRICEX96, "");

        poolManager.unlock("");
    }

    function fairLaunchParams() external pure returns (uint256, uint256, uint256) {
        return (TOTAL_SUPPLY, CONSTANT_PRICE_DURATION, FAIR_LAUNCH_DURATION);
    }
}
