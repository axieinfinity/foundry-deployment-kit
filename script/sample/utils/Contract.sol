// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TContract } from "foundry-deployment-kit/types/Types.sol";

enum Contract {
  Sample,
  SampleProxy
}

using { key, name } for Contract global;

function key(Contract contractEnum) pure returns (TContract) {
  return TContract.wrap(uint256(keccak256(bytes(name(contractEnum)))));
}

function name(Contract contractEnum) pure returns (string memory) {
  if (contractEnum == Contract.Sample) return "Sample";
  if (contractEnum == Contract.SampleProxy) return "SampleProxy";
  revert("Contract: Unknown contract");
}
