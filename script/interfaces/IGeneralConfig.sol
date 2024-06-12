// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { IWalletConfig } from "./configs/IWalletConfig.sol";
import { IRuntimeConfig } from "./configs/IRuntimeConfig.sol";
import { IMigrationConfig } from "./configs/IMigrationConfig.sol";
import { IUserDefinedConfig } from "./configs/IUserDefinedConfig.sol";
import { TNetwork, INetworkConfig } from "./configs/INetworkConfig.sol";
import { TContract, IContractConfig } from "./configs/IContractConfig.sol";

interface IGeneralConfig is
  IWalletConfig,
  IRuntimeConfig,
  INetworkConfig,
  IContractConfig,
  IMigrationConfig,
  IUserDefinedConfig
{
  function setAddress(TNetwork network, TContract contractType, address contractAddr) external;

  function getAddress(TNetwork network, TContract contractType) external view returns (address payable);

  function getAllAddresses(TNetwork network) external view returns (address payable[] memory);

  function logSenderInfo() external view;
}
