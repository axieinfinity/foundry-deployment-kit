// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { Vm } from "../../dependencies/forge-std-1.8.2/src/Vm.sol";
import { StdStyle } from "../../dependencies/forge-std-1.8.2/src/StdStyle.sol";
import { console } from "../../dependencies/forge-std-1.8.2/src/console.sol";
import { INetworkConfig } from "../interfaces/configs/INetworkConfig.sol";
import { IGeneralConfig } from "../interfaces/IGeneralConfig.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { TNetwork } from "../types/Types.sol";
import { DefaultNetwork } from "../utils/DefaultNetwork.sol";

abstract contract NetworkConfig is INetworkConfig {
  using StdStyle for *;

  Vm private constant vm = Vm(LibSharedAddress.VM);
  IGeneralConfig private constant vme = IGeneralConfig(LibSharedAddress.VME);

  uint256 private constant NULL_FORK_ID = uint256(keccak256("NULL_FORK_ID"));

  string private _deploymentRoot;
  bool private _isForkModeEnabled;
  TNetwork private _currentNetwork;
  mapping(TNetwork network => NetworkData) internal _networkDataMap;
  mapping(TNetwork network => mapping(uint256 forkBlockNumber => uint256 forkId)) internal _forkMap;

  constructor(string memory deploymentRoot) {
    _deploymentRoot = deploymentRoot;
  }

  function roll(uint256 numBlock) public virtual {
    uint256 blockTime = _networkDataMap[getCurrentNetwork()].blockTime;
    vm.roll(numBlock);
    vm.warp(blockTime * numBlock);
  }

  function warp(uint256 numSecond) public virtual {
    uint256 blockTime = _networkDataMap[getCurrentNetwork()].blockTime;
    vm.warp(numSecond);
    vm.roll(numSecond / blockTime);
  }

  function rollUpTo(uint256 untilBlockNumber) public virtual {
    uint256 blockTime = _networkDataMap[getCurrentNetwork()].blockTime;
    uint256 currBlockNumber = vm.getBlockNumber();
    uint256 newBlockTime;

    if (untilBlockNumber <= currBlockNumber) {
      newBlockTime = vm.getBlockTimestamp() - blockTime * (currBlockNumber - untilBlockNumber);
    } else {
      newBlockTime = vm.getBlockTimestamp() + blockTime * (untilBlockNumber - currBlockNumber);
    }

    vm.roll(untilBlockNumber);
    vm.warp(newBlockTime);
  }

  function warpUpTo(uint256 untilTimestamp) public virtual {
    uint256 blockTime = _networkDataMap[getCurrentNetwork()].blockTime;
    uint256 currTimestamp = vm.getBlockTimestamp();
    uint256 newBlock;

    if (untilTimestamp <= currTimestamp) {
      newBlock = vm.getBlockNumber() - (currTimestamp - untilTimestamp) / blockTime;
    } else {
      newBlock = vm.getBlockNumber() + (untilTimestamp - currTimestamp) / blockTime;
    }

    vm.roll(newBlock);
    vm.warp(untilTimestamp);
  }

  function setForkMode(bool shouldEnable) public virtual {
    _isForkModeEnabled = shouldEnable;
  }

  function getNetworkData(TNetwork network) public view virtual returns (NetworkData memory) {
    return _networkDataMap[network];
  }

  function getDeploymentDirectory(TNetwork network) public view virtual returns (string memory dirPath) {
    string memory dirName = network.dir();
    require(bytes(dirName).length != 0, "NetworkConfig: Deployment directory not found");
    dirPath = string.concat(_deploymentRoot, dirName);
  }

  function setNetworkInfo(NetworkData memory networkData) public virtual {
    _forkMap[networkData.network][0] = tryCreateFork(networkData.chainAlias, networkData.network, 0);
    _networkDataMap[networkData.network] = networkData;
  }

  function getExplorer(TNetwork network) public view virtual returns (string memory link) {
    link = _networkDataMap[network].explorer;
  }

  function getAlias(TNetwork network) public view virtual returns (string memory networkAlias) {
    networkAlias = _networkDataMap[network].chainAlias;
    require(bytes(networkAlias).length != 0, "NetworkConfig: Network alias not found");
  }

  function getForkId(TNetwork network) public view virtual returns (uint256 forkId) {
    forkId = getForkId({ network: network, forkBlockNumber: 0 });
  }

  function getForkId(TNetwork network, uint256 forkBlockNumber) public view virtual returns (uint256 forkId) {
    forkId = _forkMap[network][forkBlockNumber];
  }

  function createFork(TNetwork network) public returns (uint256 forkId) {
    return createFork({ network: network, forkBlockNumber: 0 });
  }

  function createFork(TNetwork network, uint256 forkBlockNumber) public returns (uint256 forkId) {
    setForkMode({ shouldEnable: true });

    NetworkData memory networkData = _networkDataMap[network];
    forkId =
      _forkMap[network][forkBlockNumber] = tryCreateFork(networkData.chainAlias, networkData.network, forkBlockNumber);
  }

  function tryCreateFork(string memory chainAlias, TNetwork network, uint256 forkBlockNumber)
    public
    virtual
    returns (uint256)
  {
    uint256 currentFork = NULL_FORK_ID;

    try vm.activeFork() returns (uint256 forkId) {
      currentFork = forkId;

      // return current fork if current network is the same as the given `network`
      if (getCurrentNetwork() == network) return currentFork;
    } catch { }

    // return NULL_FORK_ID if fork mode is not enabled
    if (!_isForkModeEnabled) return NULL_FORK_ID;

    uint256 id = _forkMap[network][forkBlockNumber];

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
        console.log(string.concat("NetworkConfig: ".blue(), chainAlias, " fork created with forkId:"), forkId);
        return forkId;
      } catch {
        console.log(StdStyle.red("NetworkConfig: Cannot create fork"), chainAlias, "with url:", rpcUrl);
        return NULL_FORK_ID;
      }
    } else {
      try vm.createFork(rpcUrl, forkBlockNumber) returns (uint256 forkId) {
        console.log(
          string.concat("NetworkConfig: ".blue(), chainAlias, " fork created with forkId:").blue(),
          forkId,
          "Fork Block Number:",
          forkBlockNumber
        );

        return forkId;
      } catch {
        console.log(StdStyle.red("NetworkConfig: Cannot create fork"), chainAlias, "with url:", rpcUrl);
        return NULL_FORK_ID;
      }
    }
  }

  function switchTo(TNetwork network) public virtual {
    switchTo({ network: network, forkBlockNumber: 0 });
  }

  function switchTo(TNetwork network, uint256 forkBlockNumber) public virtual {
    uint256 forkId = _forkMap[network][forkBlockNumber];
    require(forkId != NULL_FORK_ID, "Network Config: Unexists fork!");

    vm.selectFork(forkId);
    _currentNetwork = network;

    _logCurrentForkInfo(_networkDataMap[network].chainAlias);
  }

  function switchTo(uint256 forkId) public virtual {
    vm.selectFork(forkId);
    this.logCurrentForkInfo();
  }

  function getCurrentNetwork() public view virtual returns (TNetwork network) {
    network = _currentNetwork;
    if (network == TNetwork.wrap(0x0)) network = DefaultNetwork.LocalHost.key();
  }

  function logCurrentForkInfo() public view virtual {
    _logCurrentForkInfo(_networkDataMap[getCurrentNetwork()].chainAlias);
  }

  function _logCurrentForkInfo(string memory chainAlias) internal view {
    string memory logA = string.concat(
      "Network: ".blue(),
      chainAlias.yellow(),
      " - Block Number ".blue(),
      vm.toString(vm.getBlockNumber()),
      " - Timestamp ".blue(),
      vm.toString(vm.getBlockTimestamp()),
      " - Chain ID ".blue(),
      vm.toString(block.chainid)
    );
    string memory logB = string.concat(
      " - Gas Price ".blue(),
      vm.toString(tx.gasprice / 1 gwei),
      " GWEI",
      " - Explorer ".blue(),
      _networkDataMap[getCurrentNetwork()].explorer
    );
    string memory log = string.concat(logA, logB);
    console.log(log);
  }
}
