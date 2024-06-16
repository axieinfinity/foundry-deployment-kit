// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TransparentUpgradeableProxy } from
  "../dependencies/@openzeppelin-contracts-4.9.3/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TransparentProxyV2 is TransparentUpgradeableProxy {
  /**
   * @dev Initializes the Proxy contract.
   * @param logic The address of the logic contract.
   * @param admin The address of the admin contract.
   * @param data The initialization data.
   */
  constructor(address logic, address admin, bytes memory data) payable TransparentUpgradeableProxy(logic, admin, data) { }

  /**
   * @dev Calls a function from the current implementation as specified by `data`, which should be an encoded function call.
   *
   * Requirements:
   * - Only the admin can call this function.
   *
   * Note: The proxy admin is not allowed to interact with the proxy logic through the fallback function to avoid
   * triggering some unexpected logic. This is to allow the administrator to explicitly call the proxy, please consider
   * reviewing the encoded data `_data` and the method which is called before using this.
   *
   */
  function functionDelegateCall(bytes memory data) public payable ifAdmin {
    address addr = _implementation();

    assembly ("memory-safe") {
      let result := delegatecall(gas(), addr, add(data, 32), mload(data), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
      case 0 { revert(0, returndatasize()) }
      default { return(0, returndatasize()) }
    }
  }
}
