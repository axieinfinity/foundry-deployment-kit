// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

interface IUserDefinedConfig {
  struct UserDefinedData {
    bytes _value;
  }

  function setUserDefinedConfig(string calldata key, bytes calldata value) external;

  function getUserDefinedConfig(string calldata key) external view returns (bytes memory value);

  function getAllKeys() external view returns (string[] memory);
}
