// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

interface IMigrationConfig {
  function setRawSharedArguments(bytes calldata migrationConfig) external;

  function getRawSharedArguments() external view returns (bytes memory);
}
