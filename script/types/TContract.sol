// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibString } from "../../lib/solady/src/utils/LibString.sol";

type TContract is bytes32;

using LibString for bytes32;

using { contractName, contractEq as ==, contractNeq as != } for TContract global;

function contractName(TContract contractType) pure returns (string memory) {
  return TContract.unwrap(contractType).unpackOne();
}

function contractEq(TContract a, TContract b) pure returns (bool) {
  return TContract.unwrap(a) == TContract.unwrap(b);
}

function contractNeq(TContract a, TContract b) pure returns (bool) {
  return TContract.unwrap(a) != TContract.unwrap(b);
}
