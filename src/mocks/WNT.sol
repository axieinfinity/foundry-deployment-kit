// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC20 } from "../../dependencies/@openzeppelin-contracts-4.9.3//token/ERC20/ERC20.sol";
import { IWNT } from "./interfaces/IWNT.sol";

/// @notice Minimalist and modern Wrapped Ether implementation.
/// @author Solmate
/// (https://github.com/transmissions11/solmate/blob/main/src/tokens/WETH.sol)
/// @author Inspired by WETH9
/// (https://github.com/dapphub/ds-weth/blob/master/src/weth9.sol)
contract WNT is IWNT, ERC20 {
  constructor(string memory name_, string memory symbol_) payable ERC20(name_, symbol_) { }

  function deposit() public payable virtual {
    address sender = _msgSender();
    _mint(sender, msg.value);
    emit Deposit(sender, msg.value);
  }

  function withdraw(uint256 amount) public virtual {
    address sender = _msgSender();
    _burn(sender, amount);
    emit Withdrawal(sender, amount);
    (bool success,) = sender.call{ value: amount }("");
    require(success, "WNT: Native transfer failed");
  }

  receive() external payable virtual {
    deposit();
  }
}
