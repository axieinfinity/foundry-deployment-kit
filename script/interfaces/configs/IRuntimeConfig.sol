// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRuntimeConfig {
  struct Option {
    bool generateArtifact;
    bool trezor;
    bool disablePostcheck;
  }

  function isPostChecking() external view returns (bool);

  function setPostCheckingStatus(bool status) external;

  function getCommand() external view returns (string memory);

  function resolveCommand(string calldata command) external;

  function getRuntimeConfig() external view returns (Option memory options);
}
