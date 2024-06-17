// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { LibString } from "../../dependencies/solady-0.0.206/src/utils/LibString.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { Vm } from "../../dependencies/forge-std-1.8.2/src/Vm.sol";

type TNetwork is bytes32;

using LibString for bytes32;

using { chainAlias, eq as ==, neq as !=, env, dir } for TNetwork global;

function chainAlias(TNetwork network) pure returns (string memory) {
  return TNetwork.unwrap(network).unpackOne();
}

function env(TNetwork network) pure returns (string memory) {
  Vm vm = Vm(LibSharedAddress.VM);
  return string.concat(vm.toUppercase(vm.replace(chainAlias(network), "-", "_")), "_PK");
}

function dir(TNetwork network) pure returns (string memory) {
  return string.concat(chainAlias(network), "/");
}

function eq(TNetwork a, TNetwork b) pure returns (bool) {
  return TNetwork.unwrap(a) == TNetwork.unwrap(b);
}

function neq(TNetwork a, TNetwork b) pure returns (bool) {
  return TNetwork.unwrap(a) != TNetwork.unwrap(b);
}
