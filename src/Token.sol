pragma solidity 0.8.25;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract Token is ERC20 {
    constructor(string memory _name, string memory _symbol, uint8 decimals, uint256 _totalSupply)
        ERC20(_name, _symbol, decimals)
    {
        _mint(msg.sender, _totalSupply);
    }
}
