// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "../../../dependencies/@openzeppelin-4.9.3/contracts/access/Ownable.sol";
import "./InitializableTesting.sol";

contract SampleProxyForTestingPurpose2 is Ownable, InitializableTesting {
  uint256[50] private __gap;

  string internal _message;
  address internal _addr;

  constructor() {
    _disableInitializers();
  }

  function initialize(string calldata message) public {
    _message = message;
  }

  function abcXYZ(string calldata message) public { }

  function setMessage(string memory message) public {
    _message = message;
  }

  function getMessage() public view returns (string memory) {
    return _message;
  }
}
