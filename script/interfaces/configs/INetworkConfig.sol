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
  }

  function setNetworkInfo(
    uint256 chainId,
    TNetwork network,
    string calldata chainAlias,
    string calldata deploymentDir,
    string calldata privateKeyEnvLabel
  ) external;

  function switchTo(TNetwork network) external;

  function tryCreateFork(string calldata chainAlias, uint256 chainId) external returns (uint256);

  function getDeploymentDirectory(TNetwork network) external view returns (string memory dirPath);

  function getCurrentNetwork() external view returns (TNetwork network);

  function getPrivateKeyEnvLabel(TNetwork network) external view returns (string memory privateKeyEnvLabel);

  function getNetworkByChainId(uint256 chainId) external view returns (TNetwork network);
}
