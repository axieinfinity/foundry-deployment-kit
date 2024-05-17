// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IUserDefinedConfig {
  struct UserDefinedData {
    bytes _value;
  }

  function setUserDefinedConfig(string calldata key, bytes calldata value) external;

  function getUserDefinedConfig(string calldata key) external view returns (bytes memory value);

  function getAllKeys() external view returns (string[] memory);
}
