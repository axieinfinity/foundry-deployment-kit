// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { Vm, VmSafe } from "../dependencies/forge-std-1.8.2/src/Vm.sol";
import { StdStyle } from "../dependencies/forge-std-1.8.2/src/StdStyle.sol";
import { console } from "../dependencies/forge-std-1.8.2/src/console.sol";
import { WalletConfig } from "./configs/WalletConfig.sol";
import { RuntimeConfig } from "./configs/RuntimeConfig.sol";
import { MigrationConfig } from "./configs/MigrationConfig.sol";
import { UserDefinedConfig } from "./configs/UserDefinedConfig.sol";
import { TNetwork, NetworkConfig } from "./configs/NetworkConfig.sol";
import { EnumerableSet, TContract, ContractConfig } from "./configs/ContractConfig.sol";
import { ISharedParameter } from "./interfaces/configs/ISharedParameter.sol";
import { DefaultNetwork } from "./utils/DefaultNetwork.sol";
import { DefaultContract } from "./utils/DefaultContract.sol";
import { LibSharedAddress } from "./libraries/LibSharedAddress.sol";

contract BaseGeneralConfig is
  RuntimeConfig,
  WalletConfig,
  ContractConfig,
  NetworkConfig,
  MigrationConfig,
  UserDefinedConfig
{
  using StdStyle for *;
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

  function setUpDefaultContracts() public {
    _setUpDefaultContracts();
  }

  function _setUpNetworks() internal virtual { }

  function _setUpContracts() internal virtual { }

  function _setUpSender() internal virtual { }

  function _setUpDefaultNetworks() private {
    setNetworkInfo(DefaultNetwork.LocalHost.data());
    setNetworkInfo(DefaultNetwork.RoninTestnet.data());
    setNetworkInfo(DefaultNetwork.RoninMainnet.data());

    _setUpNetworks();
  }

  function _setUpDefaultContracts() private {
    _contractNameMap[DefaultContract.ProxyAdmin.key()] = DefaultContract.ProxyAdmin.name();
    _contractNameMap[DefaultContract.Multicall3.key()] = DefaultContract.Multicall3.name();
    setAddress(DefaultNetwork.LocalHost.key(), DefaultContract.ProxyAdmin.key(), address(0xdead));
    setAddress(
      DefaultNetwork.RoninTestnet.key(), DefaultContract.ProxyAdmin.key(), 0x505d91E8fd2091794b45b27f86C045529fa92CD7
    );
    setAddress(
      DefaultNetwork.RoninMainnet.key(), DefaultContract.ProxyAdmin.key(), 0xA3e7d085E65CB0B916f6717da876b7bE5cC92f03
    );
    setAddress(
      DefaultNetwork.RoninMainnet.key(), DefaultContract.Multicall3.key(), 0xcA11bde05977b3631167028862bE2a173976CA11
    );
    setAddress(
      DefaultNetwork.RoninTestnet.key(), DefaultContract.Multicall3.key(), 0xcA11bde05977b3631167028862bE2a173976CA11
    );

    _setUpContracts();
  }

  function _setUpDefaultSender() private {
    _setUpSender();
  }

  function getSender() public view virtual override returns (address payable sender) {
    sender = _option.trezor ? payable(_trezorSender) : payable(_envSender);
    if (sender == address(0x0) && getCurrentNetwork() == DefaultNetwork.LocalHost.key()) {
      sender = payable(DEFAULT_SENDER);
    }
    require(sender != address(0x0), "GeneralConfig: Sender is address(0x0)");
  }

  function setAddress(TNetwork network, TContract contractType, address contractAddr) public virtual {
    string memory contractName = getContractName(contractType);
    require(
      network != TNetwork.wrap(0x0) && bytes(contractName).length != 0,
      string.concat(
        "GeneralConfig: Network or Contract Key not found. Network: ", network.chainAlias(), " Contract: ", contractName
      )
    );

    label(network, contractAddr, contractName);
    _contractAddrSet[network].add(contractAddr);
    _contractTypeMap[network][contractAddr] = contractType;
    _contractAddrMap[network][contractName] = contractAddr;
  }

  function getAddress(TNetwork network, TContract contractType) public view virtual returns (address payable) {
    return getAddressByRawData(network, getContractName(contractType));
  }

  function getAllAddresses(TNetwork network) public view virtual returns (address payable[] memory) {
    return getAllAddressesByRawData(network);
  }

  function logSenderInfo() public view {
    console.log(
      vm.getLabel(getSender()),
      string.concat("| Balance: ".magenta(), vm.toString(getSender().balance / 1 ether), " ETHER")
    );
  }

  function buildRuntimeConfig() public virtual override {
    TNetwork currNetwork = getCurrentNetwork();

    if (_option.trezor) {
      _loadTrezorAccount();
      label(currNetwork, _trezorSender, "trezor-sender");

      return;
    }

    if (_option.sender == address(0x0)) {
      string memory env = currNetwork.env();
      try this.loadENVAccount(env) {
        label(currNetwork, _envSender, "env-sender");
        return;
      } catch { }

      if (currNetwork == DefaultNetwork.LocalHost.key() || currNetwork == TNetwork.wrap(0x0)) {
        _envSender = DEFAULT_SENDER;
        label(currNetwork, _envSender, "default-local-sender");

        return;
      }

      _envSender = address(0xdead);
      label(currNetwork, _envSender, "mock-sender");

      return;
    }

    _envSender = _option.sender;
    label(currNetwork, _option.sender, "override-sender");
  }
}
