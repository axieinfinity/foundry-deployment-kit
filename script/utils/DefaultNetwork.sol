// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { LibString } from "solady/utils/LibString.sol";

import { TNetwork } from "../types/Types.sol";

enum DefaultNetwork {
  LocalHost,
  RoninTestnet,
  RoninMainnet
}

using { key, chainId, chainAlias } for DefaultNetwork global;

function chainId(
  DefaultNetwork network
) pure returns (uint256) {
  if (network == DefaultNetwork.LocalHost) return 31_337;
  if (network == DefaultNetwork.RoninMainnet) return 2020;
  if (network == DefaultNetwork.RoninTestnet) return 202_601;
  revert("DefaultNetwork: Unknown chain id");
}

function key(
  DefaultNetwork network
) pure returns (TNetwork) {
  return TNetwork.wrap(LibString.packOne(chainAlias(network)));
}

function chainAlias(
  DefaultNetwork network
) pure returns (string memory) {
  if (network == DefaultNetwork.LocalHost) return "localhost";
  if (network == DefaultNetwork.RoninTestnet) return "ronin-testnet";
  if (network == DefaultNetwork.RoninMainnet) return "ronin-mainnet";
  revert("DefaultNetwork: Unknown network alias");
}

function fromChainId(
  uint256 id
) pure returns (TNetwork) {
  if (id == chainId(DefaultNetwork.LocalHost)) return key(DefaultNetwork.LocalHost);
  if (id == chainId(DefaultNetwork.RoninTestnet)) return key(DefaultNetwork.RoninTestnet);
  if (id == chainId(DefaultNetwork.RoninMainnet)) return key(DefaultNetwork.RoninMainnet);
  return key(DefaultNetwork.LocalHost);
}
