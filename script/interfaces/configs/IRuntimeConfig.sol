// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { TNetwork } from "../../types/TNetwork.sol";

interface IRuntimeConfig {
  struct Option {
    bool trezor;
    TNetwork network;
    address sender;
    bool generateArtifact;
    bool disablePrecheck;
    bool disablePostcheck;
    uint256 forkBlockNumber;
  }

  function isPostChecking() external view returns (bool);

  function isPreChecking() external view returns (bool);

  function setPostCheckingStatus(bool status) external;

  function setPreCheckingStatus(bool status) external;

  function getCommand() external view returns (string memory);

  function resolveCommand(string calldata command) external;

  function buildRuntimeConfig() external;

  function getRuntimeConfig() external view returns (Option memory options);
}
