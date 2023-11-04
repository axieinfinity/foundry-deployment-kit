// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

type TNetwork is uint8;

type TContract is uint8;

using { eq as == } for TNetwork global;

function eq(TNetwork a, TNetwork b) pure returns (bool) {
  return TNetwork.unwrap(a) == TNetwork.unwrap(b);
}
