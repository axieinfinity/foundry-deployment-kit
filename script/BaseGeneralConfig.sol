// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm, VmSafe } from "../lib/forge-std/src/Vm.sol";
import { StdStyle } from "../lib/forge-std/src/StdStyle.sol";
import { console2 as console } from "../lib/forge-std/src/console2.sol";
import { WalletConfig } from "./configs/WalletConfig.sol";
import { RuntimeConfig } from "./configs/RuntimeConfig.sol";
import { MigrationConfig } from "./configs/MigrationConfig.sol";
import { TNetwork, NetworkConfig } from "./configs/NetworkConfig.sol";
import { EnumerableSet, TContract, ContractConfig } from "./configs/ContractConfig.sol";
import { ISharedParameter } from "./interfaces/configs/ISharedParameter.sol";
import { DefaultNetwork } from "./utils/DefaultNetwork.sol";
import { DefaultContract } from "./utils/DefaultContract.sol";
import { LibSharedAddress } from "./libraries/LibSharedAddress.sol";

contract BaseGeneralConfig is RuntimeConfig, WalletConfig, ContractConfig, NetworkConfig, MigrationConfig {
  using StdStyle for string;
  using EnumerableSet for EnumerableSet.AddressSet;

  fallback() external {
    if (msg.sig == ISharedParameter.sharedArguments.selector) {
      bytes memory returnData = getRawSharedArguments();
      assembly ("memory-safe") {
        return(add(returnData, 0x20), mload(returnData))
      }
    } else {
      revert("GeneralConfig: Unknown instruction, please rename interface to sharedArguments()");
    }
  }

  constructor(string memory absolutePath, string memory deploymentRoot)
    NetworkConfig(deploymentRoot)
    ContractConfig(absolutePath, deploymentRoot)
  {
    _setUpDefaultNetworks();
    _setUpDefaultContracts();
    _setUpDefaultSender();
    _storeDeploymentData(deploymentRoot);
  }

  function _setUpNetworks() internal virtual { }

  function _setUpContracts() internal virtual { }

  function _setUpSender() internal virtual { }

  function _setUpDefaultNetworks() private {
    setNetworkInfo(
      DefaultNetwork.Local.chainId(),
      DefaultNetwork.Local.key(),
      DefaultNetwork.Local.chainAlias(),
      DefaultNetwork.Local.deploymentDir(),
      DefaultNetwork.Local.envLabel(),
      DefaultNetwork.Local.explorer()
    );
    setNetworkInfo(
      DefaultNetwork.RoninTestnet.chainId(),
      DefaultNetwork.RoninTestnet.key(),
      DefaultNetwork.RoninTestnet.chainAlias(),
      DefaultNetwork.RoninTestnet.deploymentDir(),
      DefaultNetwork.RoninTestnet.envLabel(),
      DefaultNetwork.RoninTestnet.explorer()
    );
    setNetworkInfo(
      DefaultNetwork.RoninMainnet.chainId(),
      DefaultNetwork.RoninMainnet.key(),
      DefaultNetwork.RoninMainnet.chainAlias(),
      DefaultNetwork.RoninMainnet.deploymentDir(),
      DefaultNetwork.RoninMainnet.envLabel(),
      DefaultNetwork.RoninMainnet.explorer()
    );

    _setUpNetworks();
  }

  function _setUpDefaultContracts() private {
    _contractNameMap[DefaultContract.ProxyAdmin.key()] = DefaultContract.ProxyAdmin.name();
    setAddress(
      DefaultNetwork.RoninTestnet.key(), DefaultContract.ProxyAdmin.key(), 0x505d91E8fd2091794b45b27f86C045529fa92CD7
    );
    setAddress(
      DefaultNetwork.RoninMainnet.key(), DefaultContract.ProxyAdmin.key(), 0xA3e7d085E65CB0B916f6717da876b7bE5cC92f03
    );

    _setUpContracts();
  }

  function _setUpDefaultSender() private {
    _setUpSender();
  }

  function getSender() public view virtual override returns (address payable sender) {
    sender = _option.trezor ? payable(_trezorSender) : payable(_envSender);
    require(sender != address(0x0), "GeneralConfig: Sender is address(0x0)");
  }

  function setAddress(TNetwork network, TContract contractType, address contractAddr) public virtual {
    uint256 chainId = _networkDataMap[network].chainId;
    string memory contractName = getContractName(contractType);
    require(chainId != 0 && bytes(contractName).length != 0, "GeneralConfig: Network or Contract Key not found");

    label(chainId, contractAddr, contractName);
    _contractAddrSet[chainId].add(contractAddr);
    _contractTypeMap[chainId][contractAddr] = contractType;
    _contractAddrMap[chainId][contractName] = contractAddr;
  }

  function getAddress(TNetwork network, TContract contractType) public view virtual returns (address payable) {
    return getAddressByRawData(_networkDataMap[network].chainId, getContractName(contractType));
  }

  function getAllAddresses(TNetwork network) public view virtual returns (address payable[] memory) {
    return getAllAddressesByRawData(_networkDataMap[network].chainId);
  }

  function _handleRuntimeConfig() internal virtual override {
    if (_option.trezor) {
      _loadTrezorAccount();
      label(block.chainid, _trezorSender, "TrezorSender");
      console.log("GeneralConfig:", vm.getLabel(_trezorSender), "Enabled!");
    } else {
      string memory envLabel = getPrivateKeyEnvLabel(getCurrentNetwork());
      _loadENVAccount(envLabel);
      label(block.chainid, _envSender, "ENVSender");
      console.log("GeneralConfig:", vm.getLabel(_envSender), "Enabled!");
    }
  }
}
