// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { EnumerableSet } from "../../dependencies/@openzeppelin-contracts-4.9.3/utils/structs/EnumerableSet.sol";
import { Vm, VmSafe } from "../../dependencies/forge-std-1.8.2/src/Vm.sol";
import { console } from "../../dependencies/forge-std-1.8.2/src/console.sol";
import { StdStyle } from "../../dependencies/forge-std-1.8.2/src/StdStyle.sol";
import { LibString } from "../../dependencies/solady-0.0.206/src/utils/LibString.sol";
import { IContractConfig } from "../interfaces/configs/IContractConfig.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { vme } from "../utils/Constants.sol";
import { TContract } from "../types/TContract.sol";
import { TNetwork } from "../types/TNetwork.sol";

abstract contract ContractConfig is IContractConfig {
  using LibString for *;
  using StdStyle for *;
  using EnumerableSet for EnumerableSet.AddressSet;

  Vm private constant vm = Vm(LibSharedAddress.VM);

  string private _absolutePath;
  string private _deploymentRoot;

  mapping(TContract contractType => string contractName) internal _contractNameMap;
  mapping(TContract contractType => string absolutePath) internal _contractAbsolutePathMap;

  mapping(TNetwork networkType => EnumerableSet.AddressSet) internal _contractAddrSet;
  mapping(TNetwork networkType => mapping(string name => address addr)) internal _contractAddrMap;
  mapping(TNetwork networkType => mapping(address addr => TContract contractType)) internal _contractTypeMap;

  constructor(string memory absolutePath, string memory deploymentRoot) {
    _absolutePath = absolutePath;
    _deploymentRoot = deploymentRoot;
  }

  function getContractTypeByRawData(TNetwork network, address contractAddr)
    public
    view
    virtual
    returns (TContract contractType)
  {
    contractType = _contractTypeMap[network][contractAddr];
    require(
      TContract.unwrap(contractType) != 0x0,
      string.concat("ContractConfig(getContractTypeByRawData): ContractType not found (", contractType.name(), ")")
    );
  }

  function getContractTypeFromCurrentNetwork(address contractAddr) public view virtual returns (TContract contractType) {
    return getContractTypeByRawData(vme.getCurrentNetwork(), contractAddr);
  }

  function setContractAbsolutePathMap(TContract contractType, string memory absolutePath) public virtual {
    _contractAbsolutePathMap[contractType] = absolutePath;
  }

  function getContractName(TContract contractType) public view virtual returns (string memory name) {
    string memory contractTypeName = contractType.name();
    name = _contractNameMap[contractType];
    name = keccak256(bytes(contractTypeName)) == keccak256(bytes(name)) ? name : contractTypeName;
    require(
      bytes(name).length != 0,
      string.concat(
        "ContractConfig(getContractName): Contract Type not found (",
        contractTypeName,
        ")\n",
        "Storage Name Map: ",
        _contractNameMap[contractType]
      )
    );
  }

  function getContractAbsolutePath(TContract contractType) public view virtual returns (string memory name) {
    if (bytes(_contractAbsolutePathMap[contractType]).length != 0) {
      name = _contractAbsolutePathMap[contractType];
    } else if (bytes(_absolutePath).length != 0) {
      name = string.concat(_absolutePath, _contractNameMap[contractType], ".sol:", _contractNameMap[contractType]);
    } else {
      name = string.concat(_contractNameMap[contractType], ".sol");
    }
  }

  function getAddressFromCurrentNetwork(TContract contractType) public view virtual returns (address payable) {
    string memory contractName = getContractName(contractType);
    require(
      bytes(contractName).length != 0,
      string.concat("ContractConfig(getAddressFromCurrentNetwork): Contract Type not found (", contractType.name(), ")")
    );
    return getAddressByRawData(vme.getCurrentNetwork(), contractName);
  }

  function getAddressByString(string calldata contractName) public view virtual returns (address payable) {
    return getAddressByRawData(vme.getCurrentNetwork(), contractName);
  }

  function getAddressByRawData(TNetwork network, string memory contractName)
    public
    view
    virtual
    returns (address payable addr)
  {
    addr = payable(_contractAddrMap[network][contractName]);
    require(
      addr != address(0x0), string.concat("ContractConfig(getAddressByRawData): Address not found: ", contractName)
    );
  }

  function getAllAddressesByRawData(TNetwork network) public view virtual returns (address payable[] memory addrs) {
    address[] memory v = _contractAddrSet[network].values();
    assembly ("memory-safe") {
      addrs := v
    }
  }

  function label(TNetwork network, address contractAddr, string memory contractName) public virtual {
    vm.label(
      contractAddr,
      string.concat(
        "(",
        bytes32(TNetwork.unwrap(network)).unpackOne().blue(),
        ")",
        contractName.yellow(),
        "[",
        vm.toString(contractAddr),
        "]"
      )
    );
  }

  function _storeDeploymentData(string memory deploymentRoot) internal virtual {
    uint256 start = vm.unixTime();

    VmSafe.DirEntry[] memory deployments;
    try vm.exists(deploymentRoot) returns (bool exists) {
      if (!exists) {
        console.log("ContractConfig:", "No deployments folder, skip loading");
        return;
      }
    } catch {
      try vm.readDir(deploymentRoot) returns (VmSafe.DirEntry[] memory res) {
        deployments = res;
      } catch {
        console.log("ContractConfig:", "No deployments folder, skip loading");
        return;
      }
    }

    try vm.readDir(deploymentRoot) returns (VmSafe.DirEntry[] memory res) {
      deployments = res;
    } catch {
      console.log("ContractConfig:", "No deployments folder, skip loading");
      return;
    }

    for (uint256 i; i < deployments.length; ++i) {
      string[] memory s = vm.split(deployments[i].path, "/");
      TNetwork network = TNetwork.wrap(LibString.packOne(s[s.length - 1]));

      string memory exportedAddress;
      try vm.readFile(string.concat(deployments[i].path, "/exported_address")) returns (string memory data) {
        exportedAddress = data;
        if (bytes(exportedAddress).length == 0) continue;
      } catch {
        console.log("ContractConfig:", "No exported_address file found for folder", deployments[i].path, "skip loading");
        continue;
      }

      string[] memory entries = exportedAddress.split("\n");

      for (uint256 j; j < entries.length; ++j) {
        string[] memory data = entries[j].split("@");
        if (data.length != 2) continue;

        string memory contractName = data[0];
        address contractAddr = vm.parseAddress(data[1]);

        string memory suffix = contractName.endsWith("Proxy.json") ? "Proxy.json" : ".json";

        // remove suffix
        contractName = vm.replace(contractName, suffix, "");

        label(network, contractAddr, contractName);

        // filter out logic deployments
        if (!contractName.endsWith("Logic")) {
          _contractAddrSet[network].add(contractAddr);
          _contractAddrMap[network][contractName] = contractAddr;
          _contractTypeMap[network][contractAddr] = TContract.wrap(contractName.packOne());
        }
      }
    }

    uint256 end = vm.unixTime();
    console.log("ContractConfig:".blue(), "Deployment data loaded in", vm.toString(end - start), "milliseconds");
  }
}
