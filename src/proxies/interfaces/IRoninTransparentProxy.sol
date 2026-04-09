// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ITransparentUpgradeableProxy } from "@openzeppelin-v5/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @dev Interface for {RoninTransparentProxy}. In order to implement transparency, {RoninTransparentProxy}
 * does not implement this interface directly, and some of its functions are implemented by an internal dispatch
 * mechanism. The compiler is unaware that these functions are implemented by {RoninTransparentProxy} and will not
 * include them in the ABI so this interface must be used to interact with it.
 */
interface IRoninTransparentProxy is ITransparentUpgradeableProxy {
  function changeAdmin(
    address newAdmin
  ) external;

  function upgradeTo(
    address newImplementation
  ) external;

  function upgradeToAndCall(
    address newImplementation,
    bytes calldata data
  ) external payable;

  function implementation() external view returns (address);

  function admin() external view returns (address);
}
