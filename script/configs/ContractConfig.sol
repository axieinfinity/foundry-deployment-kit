// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { EnumerableSet } from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import { Vm, VmSafe } from "../../lib/forge-std/src/Vm.sol";
import { StdStyle } from "../../lib/forge-std/src/StdStyle.sol";
import { LibString } from "../../lib/solady/src/utils/LibString.sol";
import { IContractConfig } from "../interfaces/configs/IContractConfig.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { TContract } from "../types/Types.sol";

abstract contract ContractConfig is IContractConfig {
  using LibString for *;
  using StdStyle for string;
  using EnumerableSet for EnumerableSet.AddressSet;

  Vm private constant vm = Vm(LibSharedAddress.VM);

  string private _absolutePath;
  string private _deploymentRoot;

  mapping(TContract contractType => string contractName) internal _contractNameMap;
  mapping(TContract contractType => string absolutePath) internal _contractAbsolutePathMap;

  mapping(uint256 chainId => EnumerableSet.AddressSet) internal _contractAddrSet;
  mapping(uint256 chainId => mapping(string name => address addr)) internal _contractAddrMap;
  mapping(uint256 chainId => mapping(address addr => TContract contractType)) internal _contractTypeMap;

  constructor(string memory absolutePath, string memory deploymentRoot) {
    _absolutePath = absolutePath;
    _deploymentRoot = deploymentRoot;
  }

  function getContractTypeByRawData(uint256 chainId, address contractAddr)
    public
    view
    virtual
    returns (TContract contractType)
  {
    contractType = _contractTypeMap[chainId][contractAddr];
    require(TContract.unwrap(contractType) != bytes32(0x0), "ContractConfig: ContractType not found");
  }

  function getContractTypeFromCurrentNetwok(address contractAddr) public view virtual returns (TContract contractType) {
    return getContractTypeByRawData(block.chainid, contractAddr);
  }

  function setContractAbsolutePathMap(TContract contractType, string memory absolutePath) public virtual {
    _contractAbsolutePathMap[contractType] = absolutePath;
  }

  function getContractName(TContract contractType) public view virtual returns (string memory name) {
    string memory contractTypeName = TContract.unwrap(contractType).unpackOne();
    name = _contractNameMap[contractType];
    name = keccak256(bytes(contractTypeName)) == keccak256(bytes(name)) ? name : contractTypeName;
    require(bytes(name).length != 0, "ContractConfig: Contract Key not found");
  }

  function getContractAbsolutePath(TContract contractType) public view virtual returns (string memory name) {
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

  function getAddressFromCurrentNetwork(TContract contractType) public view virtual returns (address payable) {
    string memory contractName = getContractName(contractType);
    require(bytes(contractName).length != 0, "ContractConfig: Contract Key found");
    return getAddressByRawData(block.chainid, contractName);
  }

  function getAddressByString(string calldata contractName) public view virtual returns (address payable) {
    return getAddressByRawData(block.chainid, contractName);
  }

  function getAddressByRawData(uint256 chainId, string memory contractName)
    public
    view
    virtual
    returns (address payable addr)
  {
    addr = payable(_contractAddrMap[chainId][contractName]);
    require(addr != address(0), string.concat("ContractConfig: Address not found: ", contractName));
  }

  function getAllAddressesByRawData(uint256 chainId) public view virtual returns (address payable[] memory addrs) {
    address[] memory v = _contractAddrSet[chainId].values();
    assembly ("memory-safe") {
      addrs := v
    }
  }

  function label(uint256 chainId, address contractAddr, string memory contractName) public virtual {
    vm.label(
      contractAddr,
      string.concat("(", vm.toString(chainId).blue(), ")", contractName.yellow(), "[", vm.toString(contractAddr), "]")
    );
  }

  function _storeDeploymentData(string memory deploymentRoot) internal virtual {
    if (!vm.exists(deploymentRoot)) return;
    VmSafe.DirEntry[] memory deployments = vm.readDir(deploymentRoot);

    for (uint256 i; i < deployments.length;) {
      VmSafe.DirEntry[] memory entries = vm.readDir(deployments[i].path);
      uint256 chainId = vm.parseUint(vm.readFile(string.concat(deployments[i].path, "/.chainId")));

      for (uint256 j; j < entries.length;) {
        string memory path = entries[j].path;

        if (path.endsWith(".json")) {
          string[] memory splitteds = path.split("/");
          string memory contractName = splitteds[splitteds.length - 1];
          string memory suffix = path.endsWith("Proxy.json") ? "Proxy.json" : ".json";
          // remove suffix
          contractName = contractName.replace(suffix, "");
          string memory json = vm.readFile(path);
          address contractAddr = vm.parseJsonAddress(json, ".address");
          label(chainId, contractAddr, contractName);

          // filter out logic deployments
          if (!path.endsWith("Logic.json")) {
            _contractAddrSet[chainId].add(contractAddr);
            _contractAddrMap[chainId][contractName] = contractAddr;
            _contractTypeMap[chainId][contractAddr] = TContract.wrap(contractName.packOne());
          }
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
