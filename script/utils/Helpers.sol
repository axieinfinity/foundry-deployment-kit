// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { StdStorage, stdStorage } from "../../dependencies/forge-std-1.8.2/src/StdStorage.sol";
import { stdJson } from "../../dependencies/forge-std-1.8.2/src/StdJson.sol";
import { console } from "../../dependencies/forge-std-1.8.2/src/console.sol";
import { StdStyle } from "../../dependencies/forge-std-1.8.2/src/StdStyle.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { LibErrorHandler } from "../libraries/LibErrorHandler.sol";
import { LibString } from "../../dependencies/solady-0.0.206/src/utils/LibString.sol";
import { JSONParserLib } from "../../dependencies/solady-0.0.206/src/utils/JSONParserLib.sol";
import { TContract } from "../types/TContract.sol";

import { EMPTY_ARGS, vm, vme } from "./Constants.sol";

using StdStyle for string;
using LibString for address;
using LibString for string;
using stdJson for string;
using LibErrorHandler for bool;
using JSONParserLib for string;
using JSONParserLib for JSONParserLib.Item;
using stdStorage for StdStorage;

// // Set the balance of an account for any ERC20 token
// // Use the alternative signature to update `totalSupply`
// function deal(address token, address to, uint256 give) {
//   deal(token, to, give, false);
// }

// function deal(address token, address to, uint256 give, bool adjust) {
//   // get current balance
//   (, bytes memory balData) = token.staticcall(abi.encodeWithSelector(0x70a08231, to));
//   uint256 prevBal = abi.decode(balData, (uint256));

//   // update balance
//   stdstore.target(token).sig(0x70a08231).with_key(to).checked_write(give);

//   // update total supply
//   if (adjust) {
//     (, bytes memory totSupData) = token.staticcall(abi.encodeWithSelector(0x18160ddd));
//     uint256 totSup = abi.decode(totSupData, (uint256));
//     if (give < prevBal) {
//       totSup -= (prevBal - give);
//     } else {
//       totSup += (give - prevBal);
//     }
//     stdstore.target(token).sig(0x18160ddd).checked_write(totSup);
//   }
// }

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

function sendRawTransaction(address from, address to, uint256 gas, uint256 callValue, bytes memory callData) {
  bool success;
  bytes memory returnOrRevertData;

  prankOrBroadcast(from);

  (success, returnOrRevertData) =
    gas == 0 ? to.call{ value: callValue }(callData) : to.call{ value: callValue, gas: gas }(callData);

  if (!success) {
    if (returnOrRevertData.length != 0) {
      logDecodedError(returnOrRevertData);
    } else {
      console.log(StdStyle.red("Evm Error!"));
    }
  }
}

function logInnerCall(string memory fnName) view {
  console.log("> ", fnName.blue(), "...");
}

function cheatBroadcast(address from, address to, uint256 callValue, bytes memory callData) {
  string[] memory commandInputs = new string[](3);
  commandInputs[0] = "cast";
  commandInputs[1] = "4byte-decode";
  commandInputs[2] = vm.toString(callData);
  string memory decodedCallData = string(vm.ffi(commandInputs));

  console.log("\n");
  console.log("--------------------------- Call Detail ---------------------------");
  console.log(StdStyle.cyan("From:"), vm.getLabel(from));
  console.log(StdStyle.cyan("To:"), vm.getLabel(to));
  console.log(StdStyle.cyan("Value:"), vm.toString(callValue));
  console.log(
    StdStyle.cyan("Raw Calldata Data (Please double check using `cast pretty-calldata {raw_bytes}`):\n"),
    string.concat(" - ", vm.toString(callData))
  );
  console.log(StdStyle.cyan("Cast Decoded Call Data:"), decodedCallData);
  console.log("--------------------------------------------------------------------");

  vm.prank(from);
  (bool success, bytes memory returnOrRevertData) = to.call{ value: callValue }(callData);
  success.handleRevert(bytes4(callData), returnOrRevertData);
}

function decodeData(bytes memory data) returns (string memory decodedData) {
  string[] memory commandInputs = new string[](3);
  commandInputs[0] = "cast";
  commandInputs[1] = "4byte-decode";
  commandInputs[2] = vm.toString(data);
  decodedData = string(vm.ffi(commandInputs));
}

function loadContract(TContract contractType) view returns (address payable contractAddr) {
  return loadContract({ contractType: contractType, shouldRevert: true });
}

function loadContract(TContract contractType, bool shouldRevert) view returns (address payable contractAddr) {
  try vme.getAddressFromCurrentNetwork(contractType) returns (address payable res) {
    contractAddr = res;
  } catch {
    if (shouldRevert) {
      revert(string.concat("Utils: loadContract(TContract,bool): Contract not found. ", contractType.name()));
    } else {
      contractAddr = payable(address(0x0));
    }
  }
}

function prankOrBroadcast(address by) {
  if (vme.isPostChecking()) {
    vm.prank(by);
  } else {
    vm.broadcast(by);
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
