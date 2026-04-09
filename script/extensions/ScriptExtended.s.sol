// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";
import { LibString } from "solady/utils/LibString.sol";

import { AddressBook } from "../core/AddressBook.sol";
import { Deployer } from "../core/Deployer.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { TContract, key } from "../types/TContract.sol";
import { TNetwork } from "../types/TNetwork.sol";
import { DefaultContract } from "../utils/DefaultContract.sol";
import { DefaultNetwork } from "../utils/DefaultNetwork.sol";
import { IAddressBook } from "src/interfaces/IAddressBook.sol";
import { AddressBookRegistry } from "../core/AddressBookRegistry.sol";

abstract contract ScriptExtended is Script, AddressBook, Deployer {
  using LibString for string;
  using stdJson for string;

  string internal _deploymentRoot = "deployments/";
  IAddressBook internal immutable _addressBook;

  constructor() {
    _addressBook = IAddressBook(LibSharedAddress.ADDRESS_BOOK);
  }

  function run(
    bytes calldata callData,
    string calldata command
  ) public virtual {
    TNetwork network = _resolveNetwork(command);
    _setCurrentNetwork(network);

    _beforeRun();

    (bool success, bytes memory data) = address(this).delegatecall(callData);

    _afterRun();

    if (!success) _revert(data);
  }

  function _resolveNetwork(
    string calldata command
  ) internal view returns (TNetwork) {
    if (bytes(command).length != 0) {
      string[] memory args = string(command).split("@");
      for (uint256 i; i < args.length; ++i) {
        if (args[i].startsWith("network.")) {
          string memory networkAlias = args[i].split(".")[1];
          return TNetwork.wrap(LibString.packOne(networkAlias));
        }
        if (args[i].startsWith("network=")) {
          string memory networkAlias = args[i].split("=")[1];
          return TNetwork.wrap(LibString.packOne(networkAlias));
        }
      }
    }

    return _networkFromChainId(block.chainid);
  }

  function _networkFromChainId(
    uint256 chainId
  ) internal pure returns (TNetwork) {
    if (chainId == DefaultNetwork.LocalHost.chainId()) return DefaultNetwork.LocalHost.key();
    if (chainId == DefaultNetwork.RoninTestnet.chainId()) return DefaultNetwork.RoninTestnet.key();
    if (chainId == DefaultNetwork.RoninMainnet.chainId()) return DefaultNetwork.RoninMainnet.key();
    return DefaultNetwork.LocalHost.key();
  }

  function _beforeRun() internal virtual {
    _ensureAddressBook();
    _cacheAddressBookFromDeployments();
    _loadBroadcastPk();
  }

  function _afterRun() internal virtual { }

  function _loadBroadcastPk() internal {
    TNetwork network = getCurrentNetwork();
    string memory networkAlias = network.chainAlias();

    // Convert network alias to env var: ronin-testnet -> RONIN_TESTNET_PK
    string memory pkEnvVar = string.concat(_toUpperAlias(networkAlias).replace("-", "_"), "_PK");

    if (vm.envExists(pkEnvVar)) _setBroadcastPkFromEnv(pkEnvVar);
  }

  function _ensureAddressBook() internal {
    address book = LibSharedAddress.ADDRESS_BOOK;
    if (book.code.length == 0) {
      vm.etch(book, type(AddressBookRegistry).runtimeCode);
    }
    if (!vm.isPersistent(book)) vm.makePersistent(book);
  }

  function _cacheAddressBookFromDeployments() internal {
    TNetwork network = getCurrentNetwork();
    string memory dirPath = string.concat(_deploymentRoot, network.dir());
    string memory exportedPath = string.concat(dirPath, "exported_address");

    if (vm.exists(exportedPath)) {
      _cacheFromExported(exportedPath);
      return;
    }

    _cacheFromJson(network, dirPath, exportedPath);
  }

  function _cacheFromExported(
    string memory exportedPath
  ) internal {
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
        _addressBook.setAddress(key(contractName), contractAddr);
      }
    } catch {
      console.log("AddressBook: No exported_address for", getCurrentNetwork().chainAlias());
    }
  }

  function _cacheFromJson(
    TNetwork network,
    string memory dirPath,
    string memory exportedPath
  ) internal {
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
      _addressBook.setAddress(key(contractName), contractAddr);

      rebuilt = string.concat(rebuilt, contractName, ".json@", vm.toString(contractAddr), "\n");
    }

    if (_shouldRecordDeploymentLocal() && bytes(rebuilt).length != 0) vm.writeFile(exportedPath, rebuilt);
  }

  function _shouldRecordDeploymentLocal() private view returns (bool) {
    return vm.isContext(VmSafe.ForgeContext.ScriptBroadcast);
  }

  function _toUpperAlias(
    string memory s
  ) internal pure returns (string memory) {
    bytes memory b = bytes(s);
    for (uint256 i; i < b.length; ++i) {
      uint8 c = uint8(b[i]);
      if (c >= 97 && c <= 122) b[i] = bytes1(c - 32);
    }
    return string(b);
  }

  function _revert(
    bytes memory data
  ) private pure {
    if (data.length == 0) revert("ScriptExtended: delegatecall failed");
    assembly ("memory-safe") {
      revert(add(data, 0x20), mload(data))
    }
  }

  function setAddress(
    TNetwork,
    TContract contractType,
    address contractAddr
  ) public override {
    _recordDeployment(contractType, contractAddr);
  }

  function getAddress(
    TNetwork,
    TContract contractType
  ) public view override returns (address payable) {
    return payable(_addressBook.getAddress(contractType));
  }

  function getAddressFromCurrentNetwork(
    TContract contractType
  ) public view override returns (address payable) {
    return payable(_addressBook.getAddress(contractType));
  }

  function recordDeployment(
    TNetwork,
    string memory,
    TContract contractType,
    address contractAddr
  ) internal override {
    _recordDeployment(contractType, contractAddr);
  }

  function recordDeployment(
    TContract contractType,
    address contractAddr,
    string memory
  ) internal override {
    _recordDeployment(contractType, contractAddr);
  }

  function _recordDeployment(
    TContract contractType,
    address contractAddr
  ) internal override {
    string memory contractName = getContractName(contractType);
    vm.label(contractAddr, contractName);
    _addressBook.setAddress(contractType, contractAddr);
  }

  function _proxyAdmin() internal view override returns (address) {
    return getAddressFromCurrentNetwork(DefaultContract.ProxyAdmin.key());
  }
}
