// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

interface IMigrationScript {
  function run() external returns (address payable);

  function overrideArgs(bytes calldata args) external returns (IMigrationScript);
}
