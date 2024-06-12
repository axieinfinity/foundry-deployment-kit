// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { LibString } from "../../dependencies/solady-0.0.206/src/utils/LibString.sol";

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
