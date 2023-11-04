// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILogger {
  function generateArtifact(
    address deployer,
    address contractAddr,
    string calldata contractAbsolutePath,
    string calldata fileName,
    bytes calldata args,
    uint256 nonce
  ) external;
}
