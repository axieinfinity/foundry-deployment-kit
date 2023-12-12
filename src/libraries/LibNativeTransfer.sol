// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibErrorHandler } from "./LibErrorHandler.sol";

/**
 * @title NativeTransferHelper
 */
library LibNativeTransfer {
  using LibErrorHandler for bool;

  /**
   * @dev Transfers Native Coin and wraps result for the method caller to a recipient.
   */
  function transfer(address to, uint256 value, uint256 gasAmount) internal {
    (bool success, bytes memory returnOrRevertData) = trySendValue(to, value, gasAmount);
    success.handleRevert(bytes4(0x0), returnOrRevertData);
  }

  /**
   * @dev Unsafe send `amount` Native to the address `to`. If the sender's balance is insufficient,
   * the call does not revert.
   *
   * Note:
   * - Does not assert whether the balance of sender is sufficient.
   * - Does not assert whether the recipient accepts NATIVE.
   * - Consider using `ReentrancyGuard` before calling this function.
   *
   */
  function trySendValue(address to, uint256 value, uint256 gasAmount)
    internal
    returns (bool success, bytes memory returnOrRevertData)
  {
    (success, returnOrRevertData) = to.call{ value: value, gas: gasAmount }("");
  }
}
