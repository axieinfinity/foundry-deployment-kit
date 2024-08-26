// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Initializable } from "../../../dependencies/@openzeppelin-4.9.3/contracts/proxy/utils/Initializable.sol";
import { Initializable as InitializableV5 } from
  "../../../dependencies/@openzeppelin-v5-5.0.2/contracts/proxy/utils/Initializable.sol";
import { Ownable } from "../../../dependencies/@openzeppelin-4.9.3/contracts/access/Ownable.sol";

contract SampleProxyForTestingPurpose4 is Ownable, Initializable {
  uint256[50] private __gap;

  string internal _message;
  address internal _addr;

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
