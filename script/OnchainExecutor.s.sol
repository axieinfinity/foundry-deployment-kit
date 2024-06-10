// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "../lib/forge-std/src/StdStyle.sol";
import { console } from "../lib/forge-std/src/console.sol";
import { ScriptExtended } from "./extensions/ScriptExtended.s.sol";
import { BaseGeneralConfig } from "./BaseGeneralConfig.sol";
import { sendRawTransaction } from "./utils/Helpers.sol";
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
    vme.setPostCheckingStatus(true);
    sendRawTransaction(from, to, gas, value, callData);
    vme.setPostCheckingStatus(false);
  }

  function broadcast(address from, address to, uint256 gas, uint256 value, bytes calldata callData) public {
    sendRawTransaction(from, to, gas, value, callData);
  }
}
