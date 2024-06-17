// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { LibString } from "../../dependencies/solady-0.0.206/src/utils/LibString.sol";
import { TNetwork } from "../types/Types.sol";
import { INetworkConfig } from "../interfaces/configs/INetworkConfig.sol";

enum DefaultNetwork {
  LocalHost,
  RoninTestnet,
  RoninMainnet
}

using { key, chainId, chainAlias, explorer, data } for DefaultNetwork global;

function data(DefaultNetwork network) pure returns (INetworkConfig.NetworkData memory) {
  return INetworkConfig.NetworkData({
    network: key(network),
    blockTime: blockTime(network),
    chainAlias: chainAlias(network),
    explorer: explorer(network)
  });
}

function chainId(DefaultNetwork network) pure returns (uint256) {
  if (network == DefaultNetwork.LocalHost) return 31337;
  if (network == DefaultNetwork.RoninMainnet) return 2020;
  if (network == DefaultNetwork.RoninTestnet) return 2021;
  revert("DefaultNetwork: Unknown chain id");
}

function blockTime(DefaultNetwork network) pure returns (uint256) {
  if (network == DefaultNetwork.LocalHost) return 3;
  if (network == DefaultNetwork.RoninMainnet) return 3;
  if (network == DefaultNetwork.RoninTestnet) return 3;
  revert("DefaultNetwork: Unknown block time");
}

function explorer(DefaultNetwork network) pure returns (string memory link) {
  if (network == DefaultNetwork.RoninMainnet) return "https://app.roninchain.com/";
  if (network == DefaultNetwork.RoninTestnet) return "https://saigon-app.roninchain.com/";
  return "https://unknown-explorer.com/";
}

function key(DefaultNetwork network) pure returns (TNetwork) {
  return TNetwork.wrap(LibString.packOne(chainAlias(network)));
}

function chainAlias(DefaultNetwork network) pure returns (string memory) {
  if (network == DefaultNetwork.LocalHost) return "localhost";
  if (network == DefaultNetwork.RoninTestnet) return "ronin-testnet";
  if (network == DefaultNetwork.RoninMainnet) return "ronin-mainnet";
  revert("DefaultNetwork: Unknown network alias");
}
