// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm, VmSafe } from "lib/forge-std/src/Vm.sol";
import { LibString } from "lib/solady/src/utils/LibString.sol";
import { IContractConfig } from "../interfaces/configs/IContractConfig.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { TContract } from "../types/Types.sol";

abstract contract ContractConfig is IContractConfig {
  using LibString for string;

  Vm private constant vm = Vm(LibSharedAddress.VM);

  string private _absolutePath;
  string private _deploymentRoot;
  mapping(TContract => string contractName) internal _contractNameMap;
  mapping(TContract => string absolutePath) internal _contractAbsolutePathMap;
  mapping(uint256 chainId => mapping(string name => address addr)) internal _contractAddrMap;

  constructor(string memory absolutePath, string memory deploymentRoot) {
    _absolutePath = absolutePath;
    _deploymentRoot = deploymentRoot;
  }

  function setContractAbsolutePathMap(TContract contractType, string memory absolutePath) public {
    _contractAbsolutePathMap[contractType] = absolutePath;
  }

  function getContractName(TContract contractType) public view returns (string memory name) {
    name = _contractNameMap[contractType];
    require(bytes(name).length != 0, "Contract Key not found");
  }

  function getContractAbsolutePath(TContract contractType) public view returns (string memory name) {
    if (bytes(_contractAbsolutePathMap[contractType]).length != 0) {
      name = string.concat(
        _contractAbsolutePathMap[contractType], _contractNameMap[contractType], ".sol:", _contractNameMap[contractType]
      );
    } else if (bytes(_absolutePath).length != 0) {
      name = string.concat(_absolutePath, _contractNameMap[contractType], ".sol:", _contractNameMap[contractType]);
    } else {
      name = string.concat(_contractNameMap[contractType], ".sol");
    }
  }

  function getAddressFromCurrentNetwork(TContract contractType) public view returns (address payable) {
    string memory contractName = _contractNameMap[contractType];
    require(bytes(contractName).length != 0, "Contract Key found");
    return getAddressByRawData(block.chainid, contractName);
  }

  function getAddressByString(string calldata contractName) public view returns (address payable) {
    return getAddressByRawData(block.chainid, contractName);
  }

  function getAddressByRawData(uint256 chainId, string memory contractName) public view returns (address payable addr) {
    addr = payable(_contractAddrMap[chainId][contractName]);
    require(addr != address(0), string.concat("address not found: ", contractName));
  }

  function _storeDeploymentData(string memory deploymentRoot) internal {
    if (!vm.exists(deploymentRoot)) return;
    VmSafe.DirEntry[] memory deployments = vm.readDir(deploymentRoot);

    for (uint256 i; i < deployments.length;) {
      VmSafe.DirEntry[] memory entries = vm.readDir(deployments[i].path);
      uint256 chainId = vm.parseUint(vm.readFile(string.concat(deployments[i].path, "/.chainId")));
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
          string memory json = vm.readFile(path);
          address contractAddr = vm.parseJsonAddress(json, ".address");
          vm.label(contractAddr, string.concat(prefix, "::", contractName));
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
}
