//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LibErrorHandler {
  error ExternalCallFailed();

  function handleRevert(bool success, bytes memory returnOrRevertData) internal pure {
    if (!success) {
      if (returnOrRevertData.length != 0) {
        assembly ("memory-safe") {
          revert(add(returnOrRevertData, 0x20), mload(returnOrRevertData))
        }
      } else {
        revert ExternalCallFailed();
      }
    }
  }
}
