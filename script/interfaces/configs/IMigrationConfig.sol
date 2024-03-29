// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMigrationConfig {
  function areSharedArgumentsStored() external view returns (bool);

  function setRawSharedArguments(bytes calldata migrationConfig) external;

  function getRawSharedArguments() external view returns (bytes memory);
}
