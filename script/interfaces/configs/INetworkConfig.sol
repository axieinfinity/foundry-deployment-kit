// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { TNetwork } from "../../types/TNetwork.sol";

interface INetworkConfig {
  struct NetworkData {
    TNetwork network;
    uint256 blockTime;
    string chainAlias;
    string explorer;
  }

  function setNetworkInfo(NetworkData memory networkData) external;

  function setForkMode(bool shouldEnable) external;

  function createFork(TNetwork network) external returns (uint256 forkId);

  function createFork(TNetwork network, uint256 forkBlockNumber) external returns (uint256 forkId);

  function getExplorer(TNetwork network) external view returns (string memory link);

  function getNetworkData(TNetwork network) external view returns (NetworkData memory);

  function getForkId(TNetwork network) external view returns (uint256 forkId);

  function getAlias(TNetwork network) external view returns (string memory networkAlias);

  function switchTo(TNetwork network) external;

  function switchTo(TNetwork network, uint256 forkBlockNumber) external;

  function tryCreateFork(string calldata chainAlias, TNetwork network, uint256 forkBlockNumber)
    external
    returns (uint256);

  function switchTo(uint256 forkId) external;

  function logCurrentForkInfo() external view;

  function rollUpTo(uint256 untilBlockNumber) external;

  function roll(uint256 numBlock) external;

  function warp(uint256 numSecond) external;

  function warpUpTo(uint256 untilTimestamp) external;

  function getDeploymentDirectory(TNetwork network) external view returns (string memory dirPath);

  function getCurrentNetwork() external view returns (TNetwork network);
}
