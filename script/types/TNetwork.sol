// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibString } from "../../lib/solady/src/utils/LibString.sol";

type TNetwork is bytes32;

using LibString for bytes32;

using { networkName, networkEq as ==, networkNeq as != } for TNetwork global;

function networkName(TNetwork network) pure returns (string memory) {
  return TNetwork.unwrap(network).unpackOne();
}

function networkEq(TNetwork a, TNetwork b) pure returns (bool) {
  return TNetwork.unwrap(a) == TNetwork.unwrap(b);
}

function networkNeq(TNetwork a, TNetwork b) pure returns (bool) {
  return TNetwork.unwrap(a) != TNetwork.unwrap(b);
}
