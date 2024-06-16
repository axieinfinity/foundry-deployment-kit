// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { IMigrationConfig } from "../interfaces/configs/IMigrationConfig.sol";

abstract contract MigrationConfig is IMigrationConfig {
  bytes internal _migrationConfig;

  function setRawSharedArguments(bytes memory config) public virtual {
    _migrationConfig = config;
  }

  function getRawSharedArguments() public view virtual returns (bytes memory) {
    return _migrationConfig;
  }
}
