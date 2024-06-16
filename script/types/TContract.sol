// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { LibString } from "../../dependencies/solady-0.0.206/src/utils/LibString.sol";

type TContract is bytes32;

using LibString for bytes32;

using { name, eq as ==, neq as != } for TContract global;

function name(TContract contractType) pure returns (string memory) {
  return TContract.unwrap(contractType).unpackOne();
}

function eq(TContract a, TContract b) pure returns (bool) {
  return TContract.unwrap(a) == TContract.unwrap(b);
}

function neq(TContract a, TContract b) pure returns (bool) {
  return TContract.unwrap(a) != TContract.unwrap(b);
}
