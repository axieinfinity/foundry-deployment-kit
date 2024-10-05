// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "../../../dependencies/openzeppelin-5.0.2/contracts/access/Ownable.sol";

import { Initializable as InitializableV5 } from
  "../../../dependencies/openzeppelin-5.0.2/contracts/proxy/utils/Initializable.sol";
import { Initializable } from "../../../dependencies/openzeppelin-v4-4.9.5/contracts/proxy/utils/Initializable.sol";

contract SampleProxyForTestingPurpose is Ownable, InitializableV5 {
  uint256[50] private __gap;

  string internal _message;
  address internal _addr;

  constructor() Ownable(msg.sender) {
    // _disableInitializers();
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
