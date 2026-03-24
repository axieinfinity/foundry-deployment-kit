// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin-v5/access/Ownable.sol";

import { Initializable } from "@openzeppelin-v4/proxy/utils/Initializable.sol";
import { Initializable as InitializableV5 } from
  "@openzeppelin-v5/proxy/utils/Initializable.sol";

contract SampleProxyForTestingPurpose5 is Ownable, Initializable {
  uint256[50] private __gap;

  string internal _message;
  address internal _addr;
  uint256 internal _newVariable;

  constructor() Ownable(msg.sender) {
    _disableInitializers();
  }

  function initialize(
    string calldata message
  ) external initializer {
    _message = message;
  }

  function initializeV2(
    uint256 newValues
  ) external reinitializer(2) {
    _newVariable = newValues;
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
