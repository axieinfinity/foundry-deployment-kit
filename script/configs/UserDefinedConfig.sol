// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IUserDefinedConfig } from "../interfaces/configs/IUserDefinedConfig.sol";

abstract contract UserDefinedConfig is IUserDefinedConfig {
  function setUserDefinedConfig(string calldata slotSig, bytes32 value) external {
    bytes32 $_slot = calcSlot(slotSig);
    assembly {
      sstore($_slot, value)
    }
  }

  function getUserDefinedConfig(string calldata slotSig) external view returns (bytes32 value) {
    bytes32 $_slot = calcSlot(slotSig);
    assembly {
      value := sload($_slot)
    }
  }

  function calcSlot(string calldata slotSig) private pure returns (bytes32) {
    return keccak256(abi.encode(slotSig));
  }
}
