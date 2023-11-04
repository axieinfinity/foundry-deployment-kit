// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMigrationScript {
  function run() external returns (address payable);

  function overrideArgs(bytes calldata args) external returns (IMigrationScript);
}
