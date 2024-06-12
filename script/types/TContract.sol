// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { LibString } from "../../dependencies/solady-0.0.206/src/utils/LibString.sol";

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
