// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { IUserDefinedConfig } from "../interfaces/configs/IUserDefinedConfig.sol";

abstract contract UserDefinedConfig is IUserDefinedConfig {
  bytes32 private constant $$_UserDefinedDataStorageLocation = keccak256("@fdk.UserDefinedConfig.UserDefinedData");

  string[] private _userDefinedKeys;
  mapping(bytes32 hashKey => bool registered) private _registry;

  function setUserDefinedConfig(string calldata key, bytes calldata value) external {
    UserDefinedData storage $ = _getUserDefinedData(key);
    $._value = value;

    bytes32 hashKey = keccak256(bytes(key));

    if (!_registry[hashKey]) {
      _userDefinedKeys.push(key);
      _registry[hashKey] = true;
    }
  }

  function getUserDefinedConfig(string calldata key) external view returns (bytes memory value) {
    UserDefinedData storage $ = _getUserDefinedData(key);
    return $._value;
  }

  function getAllKeys() external view returns (string[] memory) {
    return _userDefinedKeys;
  }

  function _getUserDefinedData(string calldata key) private pure returns (UserDefinedData storage $) {
    bytes32 location = keccak256(abi.encode($$_UserDefinedDataStorageLocation, keccak256(bytes(key))));

    assembly ("memory-safe") {
      $.slot := location
    }
  }
}
