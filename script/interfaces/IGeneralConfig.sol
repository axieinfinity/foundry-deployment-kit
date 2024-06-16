// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { IWalletConfig } from "./configs/IWalletConfig.sol";
import { IRuntimeConfig } from "./configs/IRuntimeConfig.sol";
import { IMigrationConfig } from "./configs/IMigrationConfig.sol";
import { IUserDefinedConfig } from "./configs/IUserDefinedConfig.sol";
import { INetworkConfig } from "./configs/INetworkConfig.sol";
import { IContractConfig } from "./configs/IContractConfig.sol";

interface IGeneralConfig is
  IWalletConfig,
  IRuntimeConfig,
  INetworkConfig,
  IContractConfig,
  IMigrationConfig,
  IUserDefinedConfig
{
  function logSenderInfo() external view;
}
