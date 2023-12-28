// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "../lib/forge-std/src/StdStyle.sol";
import { console2 as console } from "../lib/forge-std/src/console2.sol";
import { ScriptExtended } from "./extensions/ScriptExtended.s.sol";
import { BaseGeneralConfig } from "./BaseGeneralConfig.sol";
import { LibErrorHandler } from "../lib/contract-libs/src/LibErrorHandler.sol";

contract OnchainExecutor is ScriptExtended {
  using LibErrorHandler for bool;

  modifier rollFork(uint256 forkBlock) {
    if (forkBlock != 0) {
      vm.rollFork(forkBlock);
      console.log("OnchainExecutor: Rolling to fork block number:", forkBlock);
    }
    _;
  }

  function _configByteCode() internal virtual override returns (bytes memory) {
    return abi.encodePacked(type(BaseGeneralConfig).creationCode, abi.encode("", "deployments/"));
  }

  function trace(uint256 forkBlock, address from, address to, uint256 gas, uint256 value, bytes calldata callData)
    public
    rollFork(forkBlock)
  {
    vm.prank(from);
    _sendRawTransaction(to, gas, value, callData);
  }

  function broadcast(address from, address to, uint256 gas, uint256 value, bytes calldata callData) public {
    vm.broadcast(from);
    _sendRawTransaction(to, gas, value, callData);
  }

  function _sendRawTransaction(address to, uint256 gas, uint256 value, bytes calldata callData) internal {
    bool success;
    bytes memory returnOrRevertData;

    (success, returnOrRevertData) =
      gas == 0 ? to.call{ value: value }(callData) : to.call{ value: value, gas: gas }(callData);

    if (!success) {
      if (returnOrRevertData.length != 0) {
        string[] memory commandInput = new string[](3);
        commandInput[0] = "cast";
        commandInput[1] = returnOrRevertData.length > 4 ? "4byte-decode" : "4byte";
        commandInput[2] = vm.toString(returnOrRevertData);
        bytes memory decodedError = vm.ffi(commandInput);
        console.log(StdStyle.red(string.concat("Decoded Error: ", string(decodedError))));
      } else {
        console.log(StdStyle.red("Evm Error!"));
      }
    } else {
      console.log(StdStyle.green("OnchainExecutor: Call Executed Successfully!"));
    }
  }

  function _logDecodedError(bytes memory returnOrRevertData) internal {
    if (returnOrRevertData.length != 0) {
      string[] memory commandInput = new string[](3);
      commandInput[0] = "cast";
      commandInput[1] = returnOrRevertData.length > 4 ? "4byte-decode" : "4byte";
      commandInput[2] = vm.toString(returnOrRevertData);
      bytes memory decodedError = vm.ffi(commandInput);
      console.log(StdStyle.red(string.concat("Decoded Error: ", string(decodedError))));
    }
  }
}
