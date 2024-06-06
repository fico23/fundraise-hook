pragma solidity 0.8.25;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract Token is ERC20 {
    constructor(string memory _name, string memory _symbol, uint8 decimals) ERC20(_name, _symbol, decimals) {}
}