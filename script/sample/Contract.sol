// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { LibString } from "solady/utils/LibString.sol";

import { TContract } from "../types/TContract.sol";

enum Contract {
  Sample,
  SampleProxy
}

using { key, name, artifact } for Contract global;

function name(
  Contract contractType
) pure returns (string memory) {
  if (contractType == Contract.Sample) return "Sample";
  if (contractType == Contract.SampleProxy) return "SampleProxy";
  revert("Contract: Unknown contract");
}

function key(
  Contract contractType
) pure returns (TContract) {
  return TContract.wrap(LibString.packOne(name(contractType)));
}

function artifact(
  Contract contractType
) pure returns (string memory) {
  string memory contractName = name(contractType);
  return string.concat(contractName, ".sol:", contractName);
}
