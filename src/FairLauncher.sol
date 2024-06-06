pragma solidity 0.8.25;

import {FairLaunchHook} from "./FairLaunchHook.sol";
import {Token} from "./Token.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

contract FairLauncher {
    IPoolManager public immutable poolManager;

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    function createFairLaunch(string memory name, string memory symbol, uint8 decimals, uint256 constantPriceDuration, uint256 fairLaunchDuration, uint160 sqrtPriceX96) external {
        Token token = new Token(name, symbol, decimals);

        FairLaunchHook hook = new FairLaunchHook(poolManager, constantPriceDuration, fairLaunchDuration, sqrtPriceX96);

        PoolKey memory key = PoolKey({
            
        });
        poolManager.initialize(key, sqrtPriceX96, hookData);
        // deploy hook
        // initialize pool
        // add liquidity
    }
}

