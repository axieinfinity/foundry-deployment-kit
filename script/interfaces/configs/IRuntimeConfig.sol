// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRuntimeConfig {
  struct Option {
    bool log;
    bool trezor;
  }

  function getCommand() external view returns (string memory);

  function resolveCommand(string calldata command) external;

  function getRuntimeConfig() external view returns (Option memory options);

  function setBroadcastDisableStatus(bool status) external;

  function isBroadcastDisable() external view returns (bool);
}
