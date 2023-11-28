// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TContract } from "../types/Types.sol";

enum DefaultContract { ProxyAdmin }

using { key, name } for DefaultContract global;

function key(DefaultContract defaultContract) pure returns (TContract) {
  return TContract.wrap(uint256(keccak256(bytes(name(defaultContract)))));
}

function name(DefaultContract defaultContract) pure returns (string memory) {
  if (defaultContract == DefaultContract.ProxyAdmin) return "ProxyAdmin";
  revert("DefaultContract: Unknown contract");
}
