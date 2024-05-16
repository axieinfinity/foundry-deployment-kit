// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TNetwork } from "../../types/Types.sol";

interface INetworkConfig {
  struct NetworkData {
    uint256 forkId;
    uint256 chainId;
    string chainAlias;
    string deploymentDir;
    string privateKeyEnvLabel;
    string explorer;
  }

  function setNetworkInfo(
    uint256 chainId,
    TNetwork network,
    string calldata chainAlias,
    string calldata deploymentDir,
    string calldata privateKeyEnvLabel,
    string calldata explorer
  ) external;

  function setForkMode(bool shouldEnable) external;

  function createFork(TNetwork network) external returns (uint256 forkId);

  function createFork(TNetwork network, uint256 forkBlockNumber) external returns (uint256 forkId);

  function getExplorer(TNetwork network) external view returns (string memory link);

  function getNetworkData(TNetwork network) external view returns (NetworkData memory);

  function getForkId(TNetwork network) external view returns (uint256 forkId);

  function getAlias(TNetwork network) external view returns (string memory networkAlias);

  function switchTo(TNetwork network) external;

  function switchTo(TNetwork network, uint256 forkBlockNumber) external;

  function tryCreateFork(string calldata chainAlias, uint256 chainId, uint256 forkBlockNumber)
    external
    returns (uint256);

  function switchTo(uint256 forkId) external;

  function getDeploymentDirectory(TNetwork network) external view returns (string memory dirPath);

  function getCurrentNetwork() external view returns (TNetwork network);

  function getPrivateKeyEnvLabel(TNetwork network) external view returns (string memory privateKeyEnvLabel);

  function getNetworkByChainId(uint256 chainId) external view returns (TNetwork network);
}
