// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibString } from "../../lib/solady/src/utils/LibString.sol";

type TNetwork is bytes32;

type TContract is bytes32;

using LibString for bytes32;
using { networkName, networkEq as ==, networkNeq as != } for TNetwork global;
using { contractName, contractEq as ==, contractNeq as != } for TContract global;

function networkName(TNetwork network) pure returns (string memory) {
  return TNetwork.unwrap(network).unpackOne();
}

function contractName(TContract contractType) pure returns (string memory) {
  return TContract.unwrap(contractType).unpackOne();
}

function networkEq(TNetwork a, TNetwork b) pure returns (bool) {
  return TNetwork.unwrap(a) == TNetwork.unwrap(b);
}

function networkNeq(TNetwork a, TNetwork b) pure returns (bool) {
  return TNetwork.unwrap(a) != TNetwork.unwrap(b);
}

function contractEq(TContract a, TContract b) pure returns (bool) {
  return TContract.unwrap(a) == TContract.unwrap(b);
}

function contractNeq(TContract a, TContract b) pure returns (bool) {
  return TContract.unwrap(a) != TContract.unwrap(b);
}
