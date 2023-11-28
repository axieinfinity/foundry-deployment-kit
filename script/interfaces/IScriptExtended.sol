// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TNetwork } from "../types/Types.sol";

interface IScriptExtended {
  function run(bytes calldata callData, string calldata command) external;

  function network() external view returns (TNetwork);

  function forkId() external view returns (uint256);

  function sender() external view returns (address payable);
}
