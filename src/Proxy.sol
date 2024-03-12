// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
  ITransparentUpgradeableProxy,
  TransparentUpgradeableProxy
} from "../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title Proxy
 * @dev A contract that acts as a proxy for transparent upgrades.
 */
contract Proxy is TransparentUpgradeableProxy {
  /**
   * @dev Initializes the Proxy contract.
   * @param _logic The address of the logic contract.
   * @param _admin The address of the admin contract.
   * @param _data The initialization data.
   */
  constructor(address _logic, address _admin, bytes memory _data) TransparentUpgradeableProxy(_logic, _admin, _data) { }
}
