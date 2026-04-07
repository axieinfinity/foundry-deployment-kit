// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { Script } from "forge-std/Script.sol";
import { LibString } from "solady/utils/LibString.sol";

import { AddressBook } from "../core/AddressBook.sol";
import { Deployer } from "../core/Deployer.sol";
import { TNetwork } from "../types/TNetwork.sol";
import { DefaultNetwork } from "../utils/DefaultNetwork.sol";

abstract contract ScriptExtended is Script, AddressBook, Deployer {
  using LibString for string;

  string internal _deploymentRoot = "deployments/";

  function run(
    bytes calldata callData,
    string calldata command
  ) public virtual {
    TNetwork network = _resolveNetwork(command);
    _setCurrentNetwork(network);
    _loadDeployment(network, _deploymentRoot);

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

  function _beforeRun() internal virtual { }

  function _afterRun() internal virtual { }

  function _revert(
    bytes memory data
  ) private pure {
    if (data.length == 0) revert("ScriptExtended: delegatecall failed");
    assembly ("memory-safe") {
      revert(add(data, 0x20), mload(data))
    }
  }
}
