// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TNetwork } from "../../types/Types.sol";

interface IRuntimeConfig {
  struct Option {
    bool trezor;
    TNetwork network;
    bool generateArtifact;
    bool disablePostcheck;
    uint256 forkBlockNumber;
  }

  function isPostChecking() external view returns (bool);

  function setPostCheckingStatus(bool status) external;

  function getCommand() external view returns (string memory);

  function resolveCommand(string calldata command) external;

  function buildRuntimeConfig() external;

  function getRuntimeConfig() external view returns (Option memory options);
}
