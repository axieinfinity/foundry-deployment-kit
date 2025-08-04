// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { TNetwork } from "../types/Types.sol";

interface IScriptExtended {
  function run(bytes calldata callData, string calldata command) external;
}
