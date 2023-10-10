// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDeployScript {
  function run() external returns (address payable);

  function setArgs(bytes calldata args) external returns (IDeployScript);
}
