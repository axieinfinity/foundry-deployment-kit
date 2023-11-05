// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 } from "forge-std/console2.sol";
import { INetworkConfig } from "../interfaces/configs/INetworkConfig.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { TNetwork } from "../types/Types.sol";

abstract contract NetworkConfig is INetworkConfig {
  Vm private constant vm = Vm(LibSharedAddress.VM);
  uint256 private constant NULL_FORK_ID = uint256(keccak256("NULL_FORK_ID"));

  string internal _deploymentRoot;
  bool internal _isForkModeDisabled;
  mapping(TNetwork network => NetworkData) internal _networkDataMap;
  mapping(uint256 chainId => TNetwork network) internal _networkMap;

  constructor(string memory deploymentRoot) {
    _deploymentRoot = deploymentRoot;
  }

  function getDeploymentDirectory(TNetwork network) public view returns (string memory dirPath) {
    string memory dirName = _networkDataMap[network].deploymentDir;
    require(bytes(dirName).length != 0, "GeneralConfig: Deployment dir not found");
    dirPath = string.concat(_deploymentRoot, dirName);
  }

  function setNetworkInfo(
    uint256 chainId,
    TNetwork network,
    string memory chainAlias,
    string memory deploymentDir,
    string memory privateKeyEnvLabel
  ) public {
    _networkMap[chainId] = network;
    _networkDataMap[network] =
      NetworkData(tryCreateFork(chainAlias, chainId), chainId, chainAlias, deploymentDir, privateKeyEnvLabel);
  }

  function tryCreateFork(string memory chainAlias, uint256 chainId) public returns (uint256) {
    if (_isForkModeDisabled) return NULL_FORK_ID;
    uint256 currentFork;
    try vm.activeFork() returns (uint256 forkId) {
      currentFork = forkId;
    } catch {
      _isForkModeDisabled = true;
      console2.log(StdStyle.yellow("NetworkConfig: fork mode disabled, no active fork"));
    }
    if (chainId == block.chainid) {
      console2.log(
        StdStyle.yellow(string.concat("NetworkConfig: ", chainAlias, " is already created and active at forkId:")),
        currentFork
      );
      return currentFork;
    }
    try vm.createFork(vm.rpcUrl(chainAlias)) returns (uint256 forkId) {
      console2.log(StdStyle.blue(string.concat("NetworkConfig: ", chainAlias, " fork created with forkId:")), forkId);
      return forkId;
    } catch {
      console2.log(StdStyle.red("NetworkConfig: Cannot create fork with url:"), vm.rpcUrl(chainAlias));
      return NULL_FORK_ID;
    }
  }

  function switchTo(TNetwork network) public {
    uint256 forkId = _networkDataMap[network].forkId;
    require(forkId != NULL_FORK_ID, "Network Config: Unexists fork!");
    vm.selectFork(forkId);
    require(_networkDataMap[network].chainId == block.chainid, "NetworkConfig: Switch chain failed");
  }

  function getPrivateKeyEnvLabel(TNetwork network) public view returns (string memory privateKeyEnvLabel) {
    privateKeyEnvLabel = _networkDataMap[network].privateKeyEnvLabel;
    require(bytes(privateKeyEnvLabel).length != 0, "Network Config: ENV label not found");
  }

  function getCurrentNetwork() public view returns (TNetwork network) {
    network = _networkMap[block.chainid];
  }

  function getNetworkByChainId(uint256 chainId) public view returns (TNetwork network) {
    network = _networkMap[chainId];
  }
}
