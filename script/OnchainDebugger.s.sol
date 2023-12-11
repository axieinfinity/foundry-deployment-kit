// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { ScriptExtended } from "./extensions/ScriptExtended.s.sol";
import { BaseGeneralConfig } from "./BaseGeneralConfig.sol";
import { LibErrorHandler } from "../lib/contract-libs/src/LibErrorHandler.sol";

contract OnchainDebugger is ScriptExtended {
  using LibErrorHandler for bool;

  modifier rollFork(uint256 forkBlock) {
    if (forkBlock != 0) {
      vm.rollFork(forkBlock);
      console.log("OnchainDebugger: Rolling to fork block number:", forkBlock);
    }
    _;
  }

  function _configByteCode() internal virtual override returns (bytes memory) {
    return abi.encodePacked(type(BaseGeneralConfig).creationCode, abi.encode("", "deployments/"));
  }

  function trace(uint256 forkBlock, address from, address to, uint256 value, bytes calldata callData)
    public
    rollFork(forkBlock)
  {
    vm.prank(from);
    (bool success, bytes memory returnOrRevertData) = to.call{ value: value }(callData);
    success.handleRevert(msg.sig, returnOrRevertData);
  }
}
