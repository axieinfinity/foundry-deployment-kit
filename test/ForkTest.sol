// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { Test } from "forge-std/Test.sol";

import { AddressBook } from "script/core/AddressBook.sol";
import { Deployer } from "script/core/Deployer.sol";

import { TContract } from "script/types/TContract.sol";
import { TNetwork } from "script/types/TNetwork.sol";
import { DefaultContract } from "script/utils/DefaultContract.sol";
import { DefaultNetwork } from "script/utils/DefaultNetwork.sol";

/**
 * @dev Lightweight test base for consumer repos.
 *
 * Provides:
 * - Address loading from deployments/ files (AddressBook)
 * - Stateless deploy/upgrade helpers (Deployer)
 * - Fork management
 *
 * Does NOT depend on:
 * - BaseMigration / ScriptExtended
 * - BaseGeneralConfig / VME pattern
 * - Config mixins (RuntimeConfig, WalletConfig, etc.)
 * - Proxy source files (uses vm.getCode for artifact-based deployment)
 *
 * This means tests inheriting ForkTest compile ONLY:
 * - forge-std/Test
 * - Types (TContract, TNetwork) + solady/LibString
 * - LibProxy (forge-std/Vm)
 * - AddressBook (~90 lines)
 * - Deployer (~130 lines)
 * - The contracts being tested
 */
abstract contract ForkTest is Test, AddressBook, Deployer {
  string internal _deploymentRoot = "deployments/";

  function _setUpFork(
    TNetwork network
  ) internal virtual {
    _setUpFork(network, 0);
  }

  function _setUpFork(
    TNetwork network,
    uint256 blockNumber
  ) internal virtual {
    string memory rpcUrl = vm.rpcUrl(network.chainAlias());

    uint256 forkId;
    if (blockNumber == 0) forkId = vm.createSelectFork(rpcUrl);
    else forkId = vm.createSelectFork(rpcUrl, blockNumber);

    _setCurrentNetwork(network);
    _loadDeployment(network, _deploymentRoot);
  }

  function _setUpLocal() internal virtual {
    _setCurrentNetwork(DefaultNetwork.LocalHost.key());
    _loadDeployment(DefaultNetwork.LocalHost.key(), _deploymentRoot);
  }

  /**
   * @dev Deploy a contract behind a proxy and register it in the address book.
   */
  function _deployAndRegister(
    TContract contractType,
    string memory artifactPath,
    address proxyAdmin,
    bytes memory initData
  ) internal returns (address payable proxy) {
    proxy = payable(_deployTransparentProxy(artifactPath, proxyAdmin, initData));
    setAddress(getCurrentNetwork(), contractType, proxy);
  }

  function _deployAndRegister(
    TContract contractType,
    string memory artifactPath,
    bytes memory constructorArgs,
    address proxyAdmin,
    bytes memory initData
  ) internal returns (address payable proxy) {
    proxy = payable(_deployTransparentProxy(artifactPath, constructorArgs, proxyAdmin, initData));
    setAddress(getCurrentNetwork(), contractType, proxy);
  }

  /**
   * @dev Deploy an immutable (non-proxy) contract and register it.
   */
  function _deployImmutableAndRegister(
    TContract contractType,
    string memory artifactPath
  ) internal returns (address payable deployed) {
    deployed = payable(_deployFromArtifact(artifactPath));
    setAddress(getCurrentNetwork(), contractType, deployed);
  }

  function _deployImmutableAndRegister(
    TContract contractType,
    string memory artifactPath,
    bytes memory constructorArgs
  ) internal returns (address payable deployed) {
    deployed = payable(_deployFromArtifact(artifactPath, constructorArgs));
    setAddress(getCurrentNetwork(), contractType, deployed);
  }
}
