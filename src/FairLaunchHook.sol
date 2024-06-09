// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BeforeSwapDelta, toBeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {IFairLauncher} from "./interfaces/IFairLauncher.sol";

contract FairLaunchHook is BaseHook {
    error CantAddLiquidity();
    error FairLaunchFailed();

    // uint256 public immutable constantPriceEnd;
    // uint256 public immutable fairLaunchEnd;
    // uint160 public immutable startSqrtPriceX96;

    uint8 public fairLaunchStatus; // 0 - none, 1 - started, 2 - ended, 3 - failed

    constructor() BaseHook(IFairLauncher(msg.sender).poolManager()) {
        // (uint256 totalSupply, uint256 constantPriceDuration, uint256 fairLaunchDuration) =
        //     IFairLauncher(msg.sender).fairLaunchParams();
        // constantPriceEnd = block.timestamp + constantPriceDuration;
        // fairLaunchEnd = block.timestamp + fairLaunchDuration;
        // // startSqrtPriceX96 = sqrtPriceX96;

        // fairLaunchStatus = 1;
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
            beforeSwapReturnDelta: true, // Allow beforeSwap to return a custom delta
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
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
