// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";
import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { LibString } from "solady/utils/LibString.sol";
import { WalletConfig } from "./configs/WalletConfig.sol";
import { RuntimeConfig } from "./configs/RuntimeConfig.sol";
import { MigrationConfig } from "./configs/MigrationConfig.sol";
import { TNetwork, NetworkConfig } from "./configs/NetworkConfig.sol";
import { TContract, ContractConfig } from "./configs/ContractConfig.sol";
import { LibSharedAddress } from "./libraries/LibSharedAddress.sol";

abstract contract BaseGeneralConfig is RuntimeConfig, WalletConfig, ContractConfig, NetworkConfig, MigrationConfig {
  using LibString for string;

  Vm internal constant vm = Vm(LibSharedAddress.VM);

  constructor(string memory absolutePath, string memory deploymentRoot)
    ContractConfig(absolutePath, deploymentRoot)
    NetworkConfig(deploymentRoot)
  {
    _setUpNetworks();
    _setUpContracts();
    _setUpDefaultSender();
    _storeDeploymentData(deploymentRoot);
  }

  function _setUpNetworks() internal virtual;
  function _setUpContracts() internal virtual;
  function _setUpDefaultSender() internal virtual;

  function getSender() public view virtual override returns (address payable sender) {
    sender = _option.trezor ? payable(_trezorSender) : payable(_envSender);
    require(sender != address(0), "sender is address(0x0)");
  }

  function setAddress(TNetwork network, TContract contractType, address contractAddr) public {
    uint256 chainId = _networkDataMap[network].chainId;
    string memory contractName = _contractNameMap[contractType];
    require(chainId != 0 && bytes(contractName).length != 0, "GeneralConfig: Network or Contract Key not found");

    _contractAddrMap[chainId][contractName] = contractAddr;
  }

  function getAddress(TNetwork network, TContract contractType) public view returns (address payable) {
    return getAddressByRawData(_networkDataMap[network].chainId, _contractNameMap[contractType]);
  }

  function _handleRuntimeConfig() internal virtual override {
    if (_option.trezor) {
      string memory str = vm.envString(DEPLOYER_ENV_LABEL);
      _trezorSender = vm.parseAddress(str.replace(TREZOR_PREFIX, ""));
      console2.log(StdStyle.blue("Trezor Account:"), _trezorSender);
      vm.label(_trezorSender, "trezor::sender");
    }
  }
}
