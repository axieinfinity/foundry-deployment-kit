// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { LibString } from "../../../dependencies/solady-0.0.206/src/utils/LibString.sol";
import { TContract } from "@fdk/types/Types.sol";

enum Contract {
  tSLP,
  tAXS,
  tWRON,
  tBERRY,
  tWETH,
  Sample,
  SampleClone,
  SampleProxy
}

using { key, name } for Contract global;

function key(Contract contractEnum) pure returns (TContract) {
  return TContract.wrap(LibString.packOne(name(contractEnum)));
}

function name(Contract contractEnum) pure returns (string memory) {
  if (contractEnum == Contract.Sample) return "Sample";
  if (contractEnum == Contract.tBERRY) return "tBERRY";
  if (contractEnum == Contract.tWETH) return "tWETH";
  if (contractEnum == Contract.tSLP) return "tSLP";
  if (contractEnum == Contract.tAXS) return "tAXS";
  if (contractEnum == Contract.tWRON) return "tWRON";
  if (contractEnum == Contract.SampleClone) return "SampleClone";
  if (contractEnum == Contract.SampleProxy) return "SampleProxy";
  revert("Contract: Unknown contract");
}
