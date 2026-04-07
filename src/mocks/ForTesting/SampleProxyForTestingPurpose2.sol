// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./InitializableTesting.sol";
import { Ownable } from "@openzeppelin-v5/access/Ownable.sol";

contract SampleProxyForTestingPurpose2 is Ownable, InitializableTesting {
  uint256[50] private __gap;

  string internal _message;
  address internal _addr;

  constructor() Ownable(msg.sender) {
    _disableInitializers();
  }

  function initialize(
    string calldata message
  ) public {
    _message = message;
  }

  function abcXYZ(
    string calldata message
  ) public { }

  function setMessage(
    string memory message
  ) public {
    _message = message;
  }

  function getMessage() public view returns (string memory) {
    return _message;
  }
}
