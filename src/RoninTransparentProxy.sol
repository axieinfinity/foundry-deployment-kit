// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/transparent/TransparentUpgradeableProxy.sol)
pragma solidity ^0.8.20;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @dev Contract TransparentUpgradeableProxy from Openzeppelin v5 with the following modifications:
 * - Admin is a parameter in the constructor ( like previous versions) instead of being deployed
 * - Let the admin get access to the proxy via `functionDelegateCall`
 * - Replace _msgSender() with msg.sender
 */
contract RoninTransparentProxy is ERC1967Proxy {
  /**
   * @dev The proxy caller is the current admin, and can't fallback to the proxy target. Admin must call via
   * `adminDelegate`.
   */
  error ProxyDeniedAdminAccess();

  /**
   * @dev The caller is not the admin.
   */
  error OnlyAdmin();

  /**
   * @dev
   * An immutable address for the admin to avoid unnecessary SLOADs before each call
   * at the expense of removing the ability to change the admin once it's set.
   * This is acceptable if the admin is always a ProxyAdmin instance or similar contract
   * with its own ability to transfer the permissions to another account.
   */
  address private immutable _ADMIN;

  /**
   * @dev Initializes an upgradeable proxy managed by an instance of a {ProxyAdmin} with an `initialOwner`,
   * backed by the implementation at `logic`, and optionally initialized with `data` as explained in
   * {ERC1967Proxy-constructor}.
   */
  constructor(address logic, address admin, bytes memory data) payable ERC1967Proxy(logic, data) {
    _ADMIN = admin;
    // Set the storage value and emit an event for ERC-1967 compatibility
    ERC1967Utils.changeAdmin(_proxyAdmin());
  }

  /**
   * @dev Calls a function from the current implementation as specified by `data`, which should be an encoded function
   * call.
   *
   * Requirements:
   * - Only the admin can call this function.
   *
   * Note: The proxy admin is not allowed to interact with the proxy logic through the fallback function to avoid
   * triggering some unexpected logic. This is to allow the administrator to explicitly call the proxy, please consider
   * reviewing the encoded data `data` and the method which is called before using this.
   *
   */
  function functionDelegateCall(
    bytes memory data
  ) external payable {
    if (msg.sender != _proxyAdmin()) revert OnlyAdmin();

    address impl = _implementation();

    assembly ("memory-safe") {
      let result := delegatecall(gas(), impl, add(data, 32), mload(data), 0, 0)

      returndatacopy(0, 0, returndatasize())

      switch result
      case 0 { revert(0, returndatasize()) }
      default { return(0, returndatasize()) }
    }
  }

  /**
   * @dev Returns the admin of this proxy.
   */
  function _proxyAdmin() internal virtual returns (address admin) {
    return _ADMIN;
  }

  /**
   * @dev If caller is the admin process the call internally, otherwise transparently fallback to the proxy behavior.
   */
  function _fallback() internal virtual override {
    if (msg.sender == _proxyAdmin()) {
      if (msg.sig != ITransparentUpgradeableProxy.upgradeToAndCall.selector) revert ProxyDeniedAdminAccess();
      else _dispatchUpgradeToAndCall();
    } else {
      super._fallback();
    }
  }

  /**
   * @dev Upgrade the implementation of the proxy. See {ERC1967Utils-upgradeToAndCall}.
   *
   * Requirements:
   *
   * - If `data` is empty, `msg.value` must be zero.
   */
  function _dispatchUpgradeToAndCall() private {
    (address newImplementation, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));
    ERC1967Utils.upgradeToAndCall(newImplementation, data);
  }
}
