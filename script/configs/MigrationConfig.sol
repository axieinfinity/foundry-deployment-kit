// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IMigrationConfig } from "../interfaces/configs/IMigrationConfig.sol";

abstract contract MigrationConfig is IMigrationConfig {
  bytes internal _migrationConfig;

  function setRawSharedArguments(bytes memory config) public {
    if (_migrationConfig.length != 0) return;
    _migrationConfig = config;
  }

  function getRawSharedArguments() public view returns (bytes memory) {
    return _migrationConfig;
  }
}
