// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "../../../dependencies/openzeppelin-v5-5.1.0/contracts/access/Ownable.sol";

import { Initializable } from "../../../dependencies/openzeppelin-v4-4.9.5/contracts/proxy/utils/Initializable.sol";
import { Initializable as InitializableV5 } from
  "../../../dependencies/openzeppelin-v5-5.1.0/contracts/proxy/utils/Initializable.sol";

contract SampleProxyForTestingPurpose4 is Ownable, Initializable {
  uint256[50] private __gap;

  string internal _message;
  address internal _addr;

  constructor() Ownable(msg.sender) {
    _disableInitializers();
  }

  function initialize(
    string calldata message
  ) external initializer {
    _message = message;
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
