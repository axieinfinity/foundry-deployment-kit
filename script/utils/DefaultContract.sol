// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibString } from "../../lib/solady/src/utils/LibString.sol";
import { TContract } from "../types/Types.sol";

enum DefaultContract {
  ProxyAdmin
}

using { key, name } for DefaultContract global;

function key(DefaultContract defaultContract) pure returns (TContract) {
  return TContract.wrap(LibString.packOne(name(defaultContract)));
}

function name(DefaultContract defaultContract) pure returns (string memory) {
  if (defaultContract == DefaultContract.ProxyAdmin) return "ProxyAdmin";
  revert("DefaultContract: Unknown contract");
}
