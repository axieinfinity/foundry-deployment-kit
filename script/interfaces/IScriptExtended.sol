// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IScriptExtended {
  function run(bytes calldata callData, string calldata command) external;
}
