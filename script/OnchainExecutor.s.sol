// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { StdStyle } from "../dependencies/forge-std-1.8.2/src/StdStyle.sol";
import { console } from "../dependencies/forge-std-1.8.2/src/console.sol";
import { ScriptExtended } from "./extensions/ScriptExtended.s.sol";
import { BaseGeneralConfig } from "./BaseGeneralConfig.sol";
import { sendRawTransaction } from "./utils/Helpers.sol";
import { LibErrorHandler } from "./libraries/LibErrorHandler.sol";

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
