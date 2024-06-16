// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
  ITransparentUpgradeableProxy,
  TransparentUpgradeableProxy
} from "../dependencies/@openzeppelin-contracts-4.9.3//proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title TransparentProxyOZv4_9_5
 * @dev A contract that acts as a proxy for transparent upgrades.
 */
contract TransparentProxyOZv4_9_5 is TransparentUpgradeableProxy {
  /**
   * @dev Initializes the Proxy contract.
   * @param logic The address of the logic contract.
   * @param admin The address of the admin contract.
   * @param data The initialization data.
   */
  constructor(address logic, address admin, bytes memory data) payable TransparentUpgradeableProxy(logic, admin, data) { }
}
