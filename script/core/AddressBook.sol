// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { CommonBase } from "forge-std/Base.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";
import { LibString } from "solady/utils/LibString.sol";

import { TContract } from "../types/TContract.sol";
import { TNetwork } from "../types/TNetwork.sol";
import { DefaultNetwork } from "../utils/DefaultNetwork.sol";

/**
 * @dev Lightweight address registry that replaces the VME/BaseGeneralConfig pattern.
 *
 * Imports only: forge-std/Base, types, LibSharedAddress, DefaultNetwork.
 * Does NOT import: config mixins, migration scripts, proxy contracts, or heavy libraries.
 *
 * Consumer tests inherit this to get address loading without compiling the full migration stack.
 */
abstract contract AddressBook is CommonBase {
  using LibString for *;
  using stdJson for string;

  TNetwork private _currentNetwork;

  mapping(TContract contractType => string contractName) internal _contractNameMap;
  mapping(TNetwork network => mapping(string name => address addr)) internal _contractAddrMap;

  function _setCurrentNetwork(
    TNetwork network
  ) internal {
    _currentNetwork = network;
  }

  function getCurrentNetwork() public view virtual returns (TNetwork network) {
    network = _currentNetwork;
    if (network == TNetwork.wrap(0x0)) network = DefaultNetwork.LocalHost.key();
  }

  function setAddress(
    TNetwork network,
    TContract contractType,
    address contractAddr
  ) public virtual {
    string memory cName = getContractName(contractType);
    vm.label(contractAddr, cName);
    _contractAddrMap[network][cName] = contractAddr;
  }

  function getAddress(
    TNetwork network,
    TContract contractType
  ) public view virtual returns (address payable) {
    string memory cName = getContractName(contractType);
    address addr = _contractAddrMap[network][cName];
    require(addr != address(0x0), string.concat("AddressBook: Address not found: ", cName));
    return payable(addr);
  }

  function getAddressFromCurrentNetwork(
    TContract contractType
  ) public view virtual returns (address payable) {
    return getAddress(getCurrentNetwork(), contractType);
  }

  function getContractName(
    TContract contractType
  ) public view virtual returns (string memory cName) {
    string memory typeName = contractType.name();
    cName = _contractNameMap[contractType];
    if (bytes(cName).length == 0) cName = typeName;
    require(bytes(cName).length != 0, string.concat("AddressBook: Contract name not found: ", typeName));
  }

  /// @dev Load addresses from a `deployments/{network}/exported_address` file.
  /// File format: one entry per line, `ContractName` followed by the at-sign and the hex address.
  function _loadDeployment(
    TNetwork network,
    string memory deploymentRoot
  ) internal virtual {
    string memory dirPath = string.concat(deploymentRoot, network.dir());
    string memory exportedPath = string.concat(dirPath, "exported_address");

    if (vm.exists(exportedPath)) {
      _loadFromExported(network, exportedPath);
      return;
    }

    _rebuildFromJson(network, dirPath, exportedPath);
  }

  function recordDeployment(
    TNetwork network,
    string memory deploymentRoot,
    TContract contractType,
    address contractAddr
  ) internal virtual {
    string memory contractName = getContractName(contractType);
    setAddress(network, contractType, contractAddr);
    if (!_shouldRecordDeployment()) return;
    _appendExportedAddress(deploymentRoot, network, contractName, contractAddr);
  }

  function recordDeployment(
    TContract contractType,
    address contractAddr,
    string memory deploymentRoot
  ) internal virtual {
    recordDeployment(getCurrentNetwork(), deploymentRoot, contractType, contractAddr);
  }

  function _loadFromExported(
    TNetwork network,
    string memory exportedPath
  ) private {
    try vm.readFile(exportedPath) returns (string memory data) {
      if (bytes(data).length == 0) return;

      string[] memory entries = vm.split(data, "\n");

      for (uint256 i; i < entries.length; ++i) {
        if (bytes(entries[i]).length == 0) continue;
        string[] memory parts = vm.split(entries[i], "@");
        if (parts.length != 2) continue;

        string memory contractName = vm.replace(vm.replace(parts[0], "Proxy.json", ""), ".json", "");
        address contractAddr = vm.parseAddress(parts[1]);

        vm.label(contractAddr, contractName);
        _contractAddrMap[network][contractName] = contractAddr;
      }
    } catch {
      console.log("AddressBook: No exported_address for", network.chainAlias());
    }
  }

  function _rebuildFromJson(
    TNetwork network,
    string memory dirPath,
    string memory exportedPath
  ) private {
    VmSafe.DirEntry[] memory entries;
    try vm.readDir(dirPath) returns (VmSafe.DirEntry[] memory res) {
      entries = res;
    } catch {
      console.log("AddressBook: No deployments folder for", network.chainAlias());
      return;
    }

    string memory rebuilt;

    for (uint256 i; i < entries.length; ++i) {
      if (entries[i].isDir) continue;

      string[] memory parts = vm.split(entries[i].path, "/");
      string memory fileName = parts[parts.length - 1];

      if (fileName.eq(".chainId") || fileName.eq("exported_address")) continue;
      if (!fileName.endsWith(".json")) continue;

      string memory json = vm.readFile(entries[i].path);
      if (bytes(json).length == 0) continue;

      address contractAddr = json.readAddress(".address");
      if (contractAddr == address(0)) continue;

      string memory contractName =
        fileName.endsWith("Proxy.json") ? fileName.replace("Proxy.json", "") : fileName.replace(".json", "");

      vm.label(contractAddr, contractName);
      _contractAddrMap[network][contractName] = contractAddr;

      rebuilt = string.concat(rebuilt, contractName, ".json@", vm.toString(contractAddr), "\n");
    }

    if (_shouldRecordDeployment() && bytes(rebuilt).length != 0) vm.writeFile(exportedPath, rebuilt);
  }

  function _appendExportedAddress(
    string memory deploymentRoot,
    TNetwork network,
    string memory contractName,
    address contractAddr
  ) private {
    if (!_shouldRecordDeployment()) return;

    string memory dirPath = string.concat(deploymentRoot, network.dir());
    if (!vm.exists(dirPath)) vm.createDir(dirPath, true);

    string memory exportedPath = string.concat(dirPath, "exported_address");
    string memory existing = vm.exists(exportedPath) ? vm.readFile(exportedPath) : "";
    string memory line = string.concat(contractName, ".json@", vm.toString(contractAddr), "\n");
    vm.writeFile(exportedPath, string.concat(existing, line));
  }

  function _shouldRecordDeployment() private view returns (bool) {
    return vm.isContext(VmSafe.ForgeContext.ScriptBroadcast);
  }
}
