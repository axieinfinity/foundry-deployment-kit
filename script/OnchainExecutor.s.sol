// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "../lib/forge-std/src/StdStyle.sol";
import { console } from "../lib/forge-std/src/console.sol";
import { ScriptExtended } from "./extensions/ScriptExtended.s.sol";
import { BaseGeneralConfig } from "./BaseGeneralConfig.sol";
import { sendRawTransaction } from "./utils/Utils.sol";
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

  function _configCreationData() internal virtual override returns (bytes memory creationCode, bytes memory callData) {
    creationCode = type(BaseGeneralConfig).creationCode;
    callData = abi.encodeCall(BaseGeneralConfig.initialize, ());
  }

  function trace(uint256 forkBlock, address from, address to, uint256 gas, uint256 value, bytes calldata callData)
    public
    rollFork(forkBlock)
  {
    vm.prank(from);
    sendRawTransaction(to, gas, value, callData);
  }

  function broadcast(address from, address to, uint256 gas, uint256 value, bytes calldata callData) public {
    vm.broadcast(from);
    sendRawTransaction(to, gas, value, callData);
  }
}
