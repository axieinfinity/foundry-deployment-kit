// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Initializable } from "../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

contract SampleProxy is Initializable {
  uint256[50] private __gap;

  string internal _message;

  constructor() {
    _disableInitializers();
  }

  function initialize(string calldata message) external initializer {
    _message = message;
  }

  function setMessage(string memory message) public {
    _message = message;
  }

  function getMessage() public view returns (string memory) {
    return _message;
  }
}
