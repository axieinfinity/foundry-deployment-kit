// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IMigrationConfig } from "../interfaces/configs/IMigrationConfig.sol";

abstract contract MigrationConfig is IMigrationConfig {
  bytes internal _migrationConfig;

  function setRawSharedArguments(bytes memory config) public virtual {
    if (areSharedArgumentsStored()) return;
    _migrationConfig = config;
  }

  function areSharedArgumentsStored() public view virtual returns (bool) {
    return _migrationConfig.length != 0;
  }

  function getRawSharedArguments() public view virtual returns (bytes memory) {
    return _migrationConfig;
  }
}
