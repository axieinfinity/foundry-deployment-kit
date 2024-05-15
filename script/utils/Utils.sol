// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { stdJson } from "../../lib/forge-std/src/StdJson.sol";
import { console } from "../../lib/forge-std/src/console.sol";
import { StdStyle } from "../../lib/forge-std/src/StdStyle.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { LibErrorHandler } from "../../lib/contract-libs/src/LibErrorHandler.sol";
import { LibString } from "../../lib/solady/src/utils/LibString.sol";
import { JSONParserLib } from "../../lib/solady/src/utils/JSONParserLib.sol";
import { TContract } from "../types/TContract.sol";

import { EMPTY_ARGS, vm, vme } from "./Constants.sol";

using StdStyle for string;
using LibString for address;
using LibString for string;
using stdJson for string;
using LibErrorHandler for bool;
using JSONParserLib for string;
using JSONParserLib for JSONParserLib.Item;

function logDecodedError(bytes memory returnOrRevertData) {
  if (returnOrRevertData.length != 0) {
    string[] memory commandInput = new string[](3);
    commandInput[0] = "cast";
    commandInput[1] = returnOrRevertData.length > 4 ? "4byte-decode" : "4byte";
    commandInput[2] = vm.toString(returnOrRevertData);
    bytes memory decodedError = vm.ffi(commandInput);
    console.log(StdStyle.red(string.concat("Decoded Error: ", string(decodedError))));
  }
}

function sendRawTransaction(address to, uint256 gas, uint256 value, bytes calldata callData) {
  bool success;
  bytes memory returnOrRevertData;

  (success, returnOrRevertData) =
    gas == 0 ? to.call{ value: value }(callData) : to.call{ value: value, gas: gas }(callData);

  if (!success) {
    if (returnOrRevertData.length != 0) {
      logDecodedError(returnOrRevertData);
    } else {
      console.log(StdStyle.red("Evm Error!"));
    }
  } else {
    console.log(StdStyle.green("OnchainExecutor: Call Executed Successfully!"));
  }
}

function logInnerCall(string memory fnName) view {
  console.log("> ", fnName.blue(), "...");
}

function cheatBroadcast(address from, address to, bytes memory callData) {
  string[] memory commandInputs = new string[](3);
  commandInputs[0] = "cast";
  commandInputs[1] = "4byte-decode";
  commandInputs[2] = vm.toString(callData);
  string memory decodedCallData = string(vm.ffi(commandInputs));

  console.log("\n");
  console.log("--------------------------- Call Detail ---------------------------");
  console.log(StdStyle.cyan("To:"), vm.getLabel(to));
  console.log(
    StdStyle.cyan("Raw Calldata Data (Please double check using `cast pretty-calldata {raw_bytes}`):\n"),
    string.concat(" - ", vm.toString(callData))
  );
  console.log(StdStyle.cyan("Cast Decoded Call Data:"), decodedCallData);
  console.log("--------------------------------------------------------------------");

  vm.prank(from);
  (bool success, bytes memory returnOrRevertData) = to.call(callData);
  success.handleRevert(bytes4(callData), returnOrRevertData);
}

function loadContract(TContract contractType) view returns (address payable contractAddr) {
  return loadContract({ contractType: contractType, shouldRevert: true });
}

function loadContract(TContract contractType, bool shouldRevert) view returns (address payable contractAddr) {
  try vme.getAddressFromCurrentNetwork(contractType) returns (address payable res) {
    contractAddr = res;
  } catch {
    if (shouldRevert) {
      revert(string.concat("Utils: loadContract(TContract,bool): Contract not found. ", contractType.contractName()));
    } else {
      contractAddr = payable(address(0x0));
    }
  }
}

function prankOrBroadcast(address account) {
  if (vme.isPostChecking()) {
    vm.prank(account);
  } else {
    vm.broadcast(account);
  }
}

function deploySharedAddress(address where, bytes memory bytecode, string memory label) {
  deploySharedAddress(where, bytecode, EMPTY_ARGS, label);
}

function deploySharedAddress(address where, bytes memory bytecode, bytes memory callData, string memory label) {
  if (where.code.length == 0) {
    vm.makePersistent(where);
    vm.allowCheatcodes(where);
    if (bytes(label).length != 0) vm.label(where, label);
    deployCodeTo(EMPTY_ARGS, bytecode, callData, 0, where);
  }
}

function deployCodeTo(bytes memory creationCode, address where) {
  deployCodeTo(EMPTY_ARGS, creationCode, EMPTY_ARGS, 0, where);
}

function deployCodeTo(bytes memory creationCode, bytes memory callData, uint256 value, address where) {
  deployCodeTo(EMPTY_ARGS, creationCode, callData, value, where);
}

function deployCodeTo(
  bytes memory args,
  bytes memory creationCode,
  bytes memory callData,
  uint256 value,
  address where
) {
  vm.etch(where, abi.encodePacked(creationCode, args));
  (bool success, bytes memory runtimeBytecode) = where.call{ value: value }("");
  success.handleRevert(bytes4(callData), runtimeBytecode);

  vm.etch(where, runtimeBytecode);

  bytes memory revertOrRevertData;
  if (callData.length != 0) {
    (success, revertOrRevertData) = where.call(callData);
    success.handleRevert(bytes4(callData), revertOrRevertData);
  }
}

function deployCode(string memory what, bytes memory args) returns (address addr) {
  bytes memory bytecode = abi.encodePacked(vm.getCode(what), args);

  assembly ("memory-safe") {
    addr := create(0, add(bytecode, 0x20), mload(bytecode))
  }

  require(addr != address(0), "Utils: deployCode(string,bytes): Deployment failed.");
}

function deployCode(string memory what, uint256 val) returns (address addr) {
  bytes memory bytecode = vm.getCode(what);

  assembly ("memory-safe") {
    addr := create(val, add(bytecode, 0x20), mload(bytecode))
  }

  require(addr != address(0), "Utils: deployCode(string,uint256): Deployment failed.");
}
