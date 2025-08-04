// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "../../../dependencies/openzeppelin-v5-5.1.0/contracts/access/Ownable.sol";
import "./InitializableTesting.sol";

contract SampleProxyForTestingPurpose3 is Ownable, InitializableTesting {
  uint256[50] private __gap;

  string internal _message;
  address internal _addr;

  constructor() Ownable(msg.sender) {
    _disableInitializers();
  }

  function initialize(
    string calldata message
  ) public initializer {
    _message = message;
    _initialized = type(uint8).max - 10;
  }

  function setMessage(
    string memory message
  ) public {
    _message = message;
  }

  function getMessage() public view returns (string memory) {
    return _message;
  }
}
