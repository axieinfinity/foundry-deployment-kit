// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

type TNetwork is uint8;

type TContract is uint8;

using { networkEq as ==, networkNeq as != } for TNetwork global;
using { contractEq as ==, contractNeq as != } for TContract global;

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
