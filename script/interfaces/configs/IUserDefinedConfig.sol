// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IUserDefinedConfig {
  function DISABLE_LOG_ARTIFACT() external returns (string memory);

  function setUserDefinedConfig(string calldata slotSig, bytes32 value) external;

  function getUserDefinedConfig(string calldata slotSig) external view returns (bytes32 value);
}
