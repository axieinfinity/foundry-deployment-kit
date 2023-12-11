// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Sample {
  string internal _message;

  constructor(string memory message) {
    _message = message;
  }

  function setMessage(string memory message) public {
    _message = message;
  }

  function getMessage() public view returns (string memory) {
    return _message;
  }
}
