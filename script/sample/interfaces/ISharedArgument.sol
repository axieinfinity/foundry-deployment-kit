// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IGeneralConfig } from "foundry-deployment-kit/interfaces/IGeneralConfig.sol";

interface ISharedArgument is IGeneralConfig {
  struct SharedParameter {
    string message;
    string proxyMessage;
  }

  function sharedArguments() external view returns (SharedParameter memory param);
}
