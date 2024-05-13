// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "../../lib/forge-std/src/Vm.sol";
import { StdStyle } from "../../lib/forge-std/src/StdStyle.sol";
import { console } from "../../lib/forge-std/src/console.sol";
import { INetworkConfig } from "../interfaces/configs/INetworkConfig.sol";
import { IGeneralConfig } from "../interfaces/IGeneralConfig.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { TNetwork } from "../types/Types.sol";

abstract contract NetworkConfig is INetworkConfig {
  using StdStyle for *;

  Vm private constant vm = Vm(LibSharedAddress.VM);
  IGeneralConfig private constant vme = IGeneralConfig(LibSharedAddress.VME);
  uint256 private constant NULL_FORK_ID = uint256(keccak256("NULL_FORK_ID"));

  string private _deploymentRoot;
  bool private _isForkModeEnabled;
  mapping(TNetwork network => NetworkData) internal _networkDataMap;
  mapping(TNetwork network => mapping(uint256 forkBlockNumber => uint256 forkId)) internal _forkMap;
  mapping(uint256 chainId => TNetwork network) internal _networkMap;

  function __NetworkConfig_init_unchained(string memory deploymentRoot) internal {
    _deploymentRoot = deploymentRoot;
  }

  function setForkMode(bool shouldEnable) public virtual {
    _isForkModeEnabled = shouldEnable;
  }

  function getNetworkData(TNetwork network) public view virtual returns (NetworkData memory) {
    return _networkDataMap[network];
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
    _forkMap[_networkMap[chainId]][0] = NULL_FORK_ID;
    _networkDataMap[_networkMap[chainId]].forkId = NULL_FORK_ID;

    _networkMap[chainId] = network;
    _networkDataMap[network] = NetworkData(
      tryCreateFork(chainAlias, chainId, 0), chainId, chainAlias, deploymentDir, privateKeyEnvLabel, explorer
    );
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
  }

  function createFork(TNetwork network) public returns (uint256 forkId) {
    return createFork({ network: network, forkBlockNumber: 0 });
  }

  function createFork(TNetwork network, uint256 forkBlockNumber) public returns (uint256 forkId) {
    setForkMode({ shouldEnable: true });

    NetworkData memory networkData = _networkDataMap[network];
    forkId = tryCreateFork(networkData.chainAlias, networkData.chainId, forkBlockNumber);

    if (forkBlockNumber == 0) {
      _networkDataMap[network].forkId = forkId;
    } else {
      _forkMap[network][forkBlockNumber] = forkId;
    }
  }

  function tryCreateFork(string memory chainAlias, uint256 chainId, uint256 forkBlockNumber)
    public
    virtual
    returns (uint256)
  {
    uint256 currentFork = NULL_FORK_ID;

    try vm.activeFork() returns (uint256 forkId) {
      currentFork = forkId;
    } catch { }

    // return current fork if chainId is the same as the current chain id
    if (chainId == block.chainid) return currentFork;

    // return NULL_FORK_ID if fork mode is not enabled
    if (!_isForkModeEnabled) return NULL_FORK_ID;

    uint256 id = forkBlockNumber == 0
      ? _networkDataMap[_networkMap[chainId]].forkId
      : _forkMap[_networkMap[chainId]][forkBlockNumber];

    if (id != NULL_FORK_ID) {
      // return if fork id is not NULL_FORK_ID and fork id != 0
      if (id != 0) return id;

      // if id is not NULL_FORK_ID, and fork id == 0 then try select the fork to see if it exists
      try vm.selectFork(id) {
        vm.selectFork(currentFork);
        return id;
      } catch { }
    }

    string memory rpcUrl = vm.rpcUrl(chainAlias);

    if (forkBlockNumber == 0) {
      try vm.createFork(rpcUrl) returns (uint256 forkId) {
        console.log(
          string.concat("NetworkConfig: ", chainAlias, " fork created with forkId:").blue(),
          forkId,
          "Fork Block Number:",
          forkBlockNumber
        );

        return forkId;
      } catch {
        console.log(StdStyle.red("NetworkConfig: Cannot create fork with url:"), rpcUrl);
        return NULL_FORK_ID;
      }
    } else {
      try vm.createFork(rpcUrl, forkBlockNumber) returns (uint256 forkId) {
        console.log(
          string.concat("NetworkConfig: ", chainAlias, " fork created with forkId:").blue(),
          forkId,
          "Fork Block Number:",
          forkBlockNumber
        );

        return forkId;
      } catch {
        console.log(StdStyle.red("NetworkConfig: Cannot create fork with url:"), rpcUrl);
        return NULL_FORK_ID;
      }
    }
  }

  function switchTo(TNetwork network) public virtual {
    switchTo({ network: network, forkBlockNumber: 0 });
  }

  function switchTo(TNetwork network, uint256 forkBlockNumber) public virtual {
    console.log(
      string.concat(
        "\n>>".blue(),
        " Switching to: ",
        _networkDataMap[network].chainAlias.yellow(),
        " - Fork Block Number ".blue(),
        vm.toString(forkBlockNumber),
        "\n"
      )
    );

    uint256 forkId = forkBlockNumber == 0 ? _networkDataMap[network].forkId : _forkMap[network][forkBlockNumber];

    require(forkId != NULL_FORK_ID, "Network Config: Unexists fork!");

    vm.selectFork(forkId);

    require(_networkDataMap[network].chainId == block.chainid, "NetworkConfig: Switch chain failed");

    _logCurrentForkInfo();
  }

  function switchTo(uint256 forkId) public virtual {
    vm.selectFork(forkId);

    TNetwork currNetwork = _networkMap[block.chainid];
    console.log(
      string.concat(
        "\n>>".blue(),
        " Switching to: ",
        _networkDataMap[currNetwork].chainAlias.yellow(),
        " - Fork Block Number ".blue(),
        vm.toString(vm.getBlockNumber()),
        "\n"
      )
    );

    _logCurrentForkInfo();
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

  function _logCurrentForkInfo() internal view {
    console.log(
      string.concat(
        "Block Number: ",
        vm.toString(vm.getBlockNumber()),
        " | ",
        "Timestamp: ",
        vm.toString(vm.getBlockTimestamp()),
        " | ",
        "Gas Price: ",
        vm.toString(tx.gasprice),
        " | ",
        "Block Gas Limit: ",
        vm.toString(block.gaslimit),
        "\n"
      ).yellow()
    );
    
    vme.logSenderInfo();
  }
}
