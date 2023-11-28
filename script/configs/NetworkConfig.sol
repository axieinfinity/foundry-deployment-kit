// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "../../lib/forge-std/src/Vm.sol";
import { StdStyle } from "../../lib/forge-std/src/StdStyle.sol";
import { console2 as console } from "../../lib/forge-std/src/console2.sol";
import { INetworkConfig } from "../interfaces/configs/INetworkConfig.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { TNetwork } from "../types/Types.sol";

abstract contract NetworkConfig is INetworkConfig {
  Vm private constant vm = Vm(LibSharedAddress.VM);
  uint256 private constant NULL_FORK_ID = uint256(keccak256("NULL_FORK_ID"));

  string internal _deploymentRoot;
  bool internal _isForkModeEnabled;
  mapping(TNetwork network => NetworkData) internal _networkDataMap;
  mapping(uint256 chainId => TNetwork network) internal _networkMap;

  constructor(string memory deploymentRoot) {
    _deploymentRoot = deploymentRoot;
  }

  function setForkMode(bool shouldEnable) public virtual {
    _isForkModeEnabled = shouldEnable;
  }

  function getDeploymentDirectory(TNetwork network) public view virtual returns (string memory dirPath) {
    string memory dirName = _networkDataMap[network].deploymentDir;
    require(bytes(dirName).length != 0, "NetworkConfig: Deployment directory not found");
    dirPath = string.concat(_deploymentRoot, dirName);
  }

  function setNetworkInfo(
    uint256 chainId,
    TNetwork network,
    string memory chainAlias,
    string memory deploymentDir,
    string memory privateKeyEnvLabel,
    string memory explorer
  ) public virtual {
    _networkMap[chainId] = network;
    _networkDataMap[network] =
      NetworkData(tryCreateFork(chainAlias, chainId), chainId, chainAlias, deploymentDir, privateKeyEnvLabel, explorer);
  }

  function getExplorer(TNetwork network) public view virtual returns (string memory link) {
    link = _networkDataMap[network].explorer;
  }

  function getAlias(TNetwork network) public view virtual returns (string memory networkAlias) {
    networkAlias = _networkDataMap[network].chainAlias;
    require(bytes(networkAlias).length != 0, "NetworkConfig: Network alias not found");
  }

  function getForkId(TNetwork network) public view virtual returns (uint256 forkId) {
    forkId = _networkDataMap[network].forkId;
    require(forkId != NULL_FORK_ID, "NetworkConfig: Network fork is not created");
  }

  function tryCreateFork(string memory chainAlias, uint256 chainId) public virtual returns (uint256) {
    uint256 currentFork;
    try vm.activeFork() returns (uint256 forkId) {
      currentFork = forkId;
    } catch {
      console.log(StdStyle.yellow("NetworkConfig: fork mode disabled, no active fork"));
      return NULL_FORK_ID;
    }
    if (chainId == block.chainid) {
      console.log(
        StdStyle.yellow(string.concat("NetworkConfig: ", chainAlias, " is already created and active at forkId:")),
        currentFork
      );
      return currentFork;
    }
    if (!_isForkModeEnabled) return NULL_FORK_ID;
    try vm.createFork(vm.rpcUrl(chainAlias)) returns (uint256 forkId) {
      console.log(StdStyle.blue(string.concat("NetworkConfig: ", chainAlias, " fork created with forkId:")), forkId);
      return forkId;
    } catch {
      console.log(StdStyle.red("NetworkConfig: Cannot create fork with url:"), vm.rpcUrl(chainAlias));
      return NULL_FORK_ID;
    }
  }

  function switchTo(TNetwork network) public virtual {
    uint256 forkId = _networkDataMap[network].forkId;
    require(forkId != NULL_FORK_ID, "Network Config: Unexists fork!");
    vm.selectFork(forkId);
    require(_networkDataMap[network].chainId == block.chainid, "NetworkConfig: Switch chain failed");
  }

  function getPrivateKeyEnvLabel(TNetwork network) public view virtual returns (string memory privateKeyEnvLabel) {
    privateKeyEnvLabel = _networkDataMap[network].privateKeyEnvLabel;
    require(bytes(privateKeyEnvLabel).length != 0, "Network Config: ENV label not found");
  }

  function getCurrentNetwork() public view virtual returns (TNetwork network) {
    network = _networkMap[block.chainid];
  }

  function getNetworkByChainId(uint256 chainId) public view virtual returns (TNetwork network) {
    network = _networkMap[chainId];
  }
}
