// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { LibString } from "../../dependencies/solady-0.0.206/src/utils/LibString.sol";
import { TContract } from "../types/Types.sol";

enum DefaultContract {
  ProxyAdmin,
  Multicall3
}

using { key, name } for DefaultContract global;

function key(DefaultContract defaultContract) pure returns (TContract) {
  return TContract.wrap(LibString.packOne(name(defaultContract)));
}

function name(DefaultContract defaultContract) pure returns (string memory) {
  if (defaultContract == DefaultContract.ProxyAdmin) return "ProxyAdmin";
  if (defaultContract == DefaultContract.Multicall3) return "Multicall3";
  revert("DefaultContract: Unknown contract");
}
