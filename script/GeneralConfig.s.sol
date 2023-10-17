// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm, VmSafe } from "forge-std/Vm.sol";
import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { LibString } from "solady/utils/LibString.sol";
import { RuntimeConfig } from "./configs/RuntimeConfig.sol";
import { ContractKey, ContractConfig } from "./configs/ContractConfig.sol";
import { Network, NetworkConfig } from "./configs/NetworkConfig.sol";

contract GeneralConfig is NetworkConfig, RuntimeConfig, ContractConfig {
  using LibString for string;

  /// @dev Trezor deployer address
  string public constant TREZOR_PREFIX = "trezor://";
  string public constant DEPLOYER_ENV_LABEL = "DEPLOYER";
  string public constant DEPLOYMENT_ROOT = "deployments/";

  Vm private immutable _vm;
  address internal _envSender;
  address internal _trezorSender;

  constructor(Vm vm) payable {
    _vm = vm;

    // by default we will read private key from .env
    _envSender = _vm.rememberKey(_vm.envUint(getPrivateKeyEnvLabel(getCurrentNetwork())));
    _storeDeploymentData();

    setAddress(Network.RoninTestnet, ContractKey.ProxyAdmin, 0x505d91E8fd2091794b45b27f86C045529fa92CD7);
  }

  function _storeDeploymentData() internal {
    VmSafe.DirEntry[] memory deployments = _vm.readDir(DEPLOYMENT_ROOT);

    for (uint256 i; i < deployments.length;) {
      VmSafe.DirEntry[] memory entries = _vm.readDir(deployments[i].path);
      uint256 chainId = _vm.parseUint(_vm.readFile(string.concat(deployments[i].path, "/.chainId")));
      string[] memory s = deployments[i].path.split("/");
      string memory prefix = s[s.length - 1];

      for (uint256 j; j < entries.length;) {
        string memory path = entries[j].path;

        if (path.endsWith(".json")) {
          string[] memory splitteds = path.split("/");
          string memory contractName = splitteds[splitteds.length - 1];
          string memory suffix = path.endsWith("Proxy.json") ? "Proxy.json" : ".json";
          // remove suffix
          assembly ("memory-safe") {
            mstore(contractName, sub(mload(contractName), mload(suffix)))
          }
          string memory json = _vm.readFile(path);
          address contractAddr = _vm.parseJsonAddress(json, ".address");
          _vm.label(contractAddr, string.concat(prefix, ".", contractName));
          // filter out logic deployments
          if (!path.endsWith("Logic.json")) _contractAddrMap[chainId][contractName] = contractAddr;
        }

        unchecked {
          ++j;
        }
      }

      unchecked {
        ++i;
      }
    }
  }

  function setRuntimeConfig(Options memory options) public virtual override {
    super.setRuntimeConfig(options);

    if (_options.trezor) {
      string memory str = _vm.envString(DEPLOYER_ENV_LABEL);
      _trezorSender = _vm.parseAddress(str.replace(TREZOR_PREFIX, ""));
      console2.log(StdStyle.blue("Trezor Account:"), _trezorSender);
      _vm.label(_trezorSender, "trezor::sender");
    } else {
      _envSender = _vm.rememberKey(_vm.envUint(getPrivateKeyEnvLabel(getCurrentNetwork())));
      console2.log(StdStyle.blue(".ENV Account:"), _envSender);
      _vm.label(_envSender, "env:sender");
    }
  }

  function getSender() public virtual returns (address payable sender) {
    sender = _options.trezor ? payable(_trezorSender) : payable(_envSender);
    require(sender != address(0), "sender is address(0x0)");
  }

  function setAddressForCurrentNetwork(ContractKey contractKey, address contractAddr) public {
    setAddress(getCurrentNetwork(), contractKey, contractAddr);
  }

  function setAddress(Network network, ContractKey contractKey, address contractAddr) public {
    uint256 chainId = _networkDataMap[network].chainId;
    string memory contractName = _contractNameMap[contractKey];
    require(chainId != 0 && bytes(contractName).length != 0, "GeneralConfig: Network or Contract Key not found");

    _contractAddrMap[chainId][contractName] = contractAddr;
  }

  function getDeploymentDirectoryFromCurrentNetwork() public view returns (string memory dirPath) {
    dirPath = getDeploymentDirectory(getCurrentNetwork());
  }

  function getDeploymentDirectory(Network network) public view returns (string memory dirPath) {
    string memory dirName = _networkDataMap[network].deploymentDir;
    require(bytes(dirName).length != 0, "GeneralConfig: Deployment dir not found");
    dirPath = string.concat(DEPLOYMENT_ROOT, dirName);
  }

  function getAddress(Network network, ContractKey contractKey) public view returns (address payable) {
    return getAddressByRawData(_networkDataMap[network].chainId, _contractNameMap[contractKey]);
  }
}
