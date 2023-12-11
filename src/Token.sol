// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
  constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) { }

  function mint(address to, uint256 supply) external {
    _mint(to, supply);
  }
}
