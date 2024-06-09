pragma solidity 0.8.25;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

interface IFairLauncher {
    function poolManager() external view returns (IPoolManager);
    function fairLaunchParams() external view returns (uint256, uint256, uint256);
}
