// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMigrationConfig {
  function setMigrationRawConfig(bytes calldata migrationConfig) external;

  function getMigrationRawConfig() external view returns (bytes memory);
}
