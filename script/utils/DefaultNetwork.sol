// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { LibString } from "../../dependencies/solady-0.0.206/src/utils/LibString.sol";
import { TNetwork } from "../types/Types.sol";
import { INetworkConfig } from "../interfaces/configs/INetworkConfig.sol";

enum DefaultNetwork {
  Local,
  RoninTestnet,
  RoninMainnet
}

using { key, name, chainId, chainAlias, envLabel, deploymentDir, explorer, data } for DefaultNetwork global;

function data(DefaultNetwork defaultNetwork) pure returns (INetworkConfig.NetworkData memory) {
  return INetworkConfig.NetworkData({
    network: key(defaultNetwork),
    chainId: chainId(defaultNetwork),
    blockTime: blockTime(defaultNetwork),
    chainAlias: chainAlias(defaultNetwork),
    deploymentDir: deploymentDir(defaultNetwork),
    privateKeyEnvLabel: envLabel(defaultNetwork),
    explorer: explorer(defaultNetwork)
  });
}

function chainId(DefaultNetwork defaultNetwork) pure returns (uint256) {
  if (defaultNetwork == DefaultNetwork.Local) return 31337;
  if (defaultNetwork == DefaultNetwork.RoninMainnet) return 2020;
  if (defaultNetwork == DefaultNetwork.RoninTestnet) return 2021;
  revert("DefaultNetwork: Unknown chain id");
}

function blockTime(DefaultNetwork defaultNetwork) pure returns (uint256) {
  if (defaultNetwork == DefaultNetwork.Local) return 3;
  if (defaultNetwork == DefaultNetwork.RoninMainnet) return 3;
  if (defaultNetwork == DefaultNetwork.RoninTestnet) return 3;
  revert("DefaultNetwork: Unknown block time");
}

function explorer(DefaultNetwork defaultNetwork) pure returns (string memory link) {
  if (defaultNetwork == DefaultNetwork.RoninMainnet) return "https://app.roninchain.com/";
  if (defaultNetwork == DefaultNetwork.RoninTestnet) return "https://saigon-app.roninchain.com/";
  return "";
}

function key(DefaultNetwork defaultNetwork) pure returns (TNetwork) {
  return TNetwork.wrap(LibString.packOne(chainAlias(defaultNetwork)));
}

function name(DefaultNetwork defaultNetwork) pure returns (string memory) {
  if (defaultNetwork == DefaultNetwork.Local) return "Local";
  if (defaultNetwork == DefaultNetwork.RoninTestnet) return "RoninTestnet";
  if (defaultNetwork == DefaultNetwork.RoninMainnet) return "RoninMainnet";
  revert("DefaultNetwork: Unknown network name");
}

function deploymentDir(DefaultNetwork defaultNetwork) pure returns (string memory) {
  return string.concat(chainAlias(defaultNetwork), "/");
}

function envLabel(DefaultNetwork defaultNetwork) pure returns (string memory) {
  if (defaultNetwork == DefaultNetwork.Local) return "LOCAL_PK";
  if (defaultNetwork == DefaultNetwork.RoninTestnet) return "TESTNET_PK";
  if (defaultNetwork == DefaultNetwork.RoninMainnet) return "MAINNET_PK";
  revert("DefaultNetwork: Unknown private key env label");
}

function chainAlias(DefaultNetwork defaultNetwork) pure returns (string memory) {
  if (defaultNetwork == DefaultNetwork.Local) return "localhost";
  if (defaultNetwork == DefaultNetwork.RoninTestnet) return "ronin-testnet";
  if (defaultNetwork == DefaultNetwork.RoninMainnet) return "ronin-mainnet";
  revert("DefaultNetwork: Unknown network alias");
}
