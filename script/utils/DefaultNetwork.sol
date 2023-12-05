// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibString } from "../../lib/solady/src/utils/LibString.sol";
import { TNetwork } from "../types/Types.sol";

enum DefaultNetwork {
  Local,
  RoninTestnet,
  RoninMainnet
}

using { key, name, chainId, chainAlias, envLabel, deploymentDir, explorer } for DefaultNetwork global;

function chainId(DefaultNetwork defaultNetwork) pure returns (uint256) {
  if (defaultNetwork == DefaultNetwork.Local) return 31337;
  if (defaultNetwork == DefaultNetwork.RoninMainnet) return 2020;
  if (defaultNetwork == DefaultNetwork.RoninTestnet) return 2021;
  revert("DefaultNetwork: Unknown chain id");
}

function explorer(DefaultNetwork defaultNetwork) pure returns (string memory link) {
  if (defaultNetwork == DefaultNetwork.RoninMainnet) return "https://app.roninchain.com/";
  if (defaultNetwork == DefaultNetwork.RoninTestnet) return "https://saigon-app.roninchain.com/";
  return "";
}

function key(DefaultNetwork defaultNetwork) pure returns (TNetwork) {
  return TNetwork.wrap(LibString.packOne(name(defaultNetwork)));
}

function name(DefaultNetwork defaultNetwork) pure returns (string memory) {
  if (defaultNetwork == DefaultNetwork.Local) return "Local";
  if (defaultNetwork == DefaultNetwork.RoninTestnet) return "RoninTestnet";
  if (defaultNetwork == DefaultNetwork.RoninMainnet) return "RoninMainnet";
  revert("DefaultNetwork: Unknown network name");
}

function deploymentDir(DefaultNetwork defaultNetwork) pure returns (string memory) {
  if (defaultNetwork == DefaultNetwork.Local) return "local/";
  if (defaultNetwork == DefaultNetwork.RoninTestnet) return "ronin-testnet/";
  if (defaultNetwork == DefaultNetwork.RoninMainnet) return "ronin-mainnet/";
  revert("DefaultNetwork: Unknown network deployment directory");
}

function envLabel(DefaultNetwork defaultNetwork) pure returns (string memory) {
  if (defaultNetwork == DefaultNetwork.Local) return "LOCAL_PK";
  if (defaultNetwork == DefaultNetwork.RoninTestnet) return "TESTNET_PK";
  if (defaultNetwork == DefaultNetwork.RoninMainnet) return "MAINNET_PK";
  revert("DefaultNetwork: Unknown private key env label");
}

function chainAlias(DefaultNetwork defaultNetwork) pure returns (string memory) {
  if (defaultNetwork == DefaultNetwork.Local) return "local";
  if (defaultNetwork == DefaultNetwork.RoninTestnet) return "ronin-testnet";
  if (defaultNetwork == DefaultNetwork.RoninMainnet) return "ronin-mainnet";
  revert("DefaultNetwork: Unknown network alias");
}
