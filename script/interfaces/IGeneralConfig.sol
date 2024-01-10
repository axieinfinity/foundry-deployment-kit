// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IWalletConfig } from "./configs/IWalletConfig.sol";
import { IRuntimeConfig } from "./configs/IRuntimeConfig.sol";
import { IMigrationConfig } from "./configs/IMigrationConfig.sol";
import { TNetwork, INetworkConfig } from "./configs/INetworkConfig.sol";
import { TContract, IContractConfig } from "./configs/IContractConfig.sol";
import { IUserDefinedConfig } from "./configs/IUserDefinedConfig.sol";

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
}
