// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/transparent/TransparentUpgradeableProxy.sol)
pragma solidity ^0.8.20;

import { ERC1967Proxy } from "@openzeppelin-v5/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC1967Utils } from "@openzeppelin-v5/proxy/ERC1967/ERC1967Utils.sol";

import { IRoninTransparentProxy } from "./interfaces/IRoninTransparentProxy.sol";

/**
 * @dev Contract TransparentUpgradeableProxy from Openzeppelin v5 with the following modifications:
 * - Admin is a parameter in the constructor (like previous versions) instead of being deployed
 * - Let the admin get access to the proxy via `functionDelegateCall`
 * - Replace _msgSender() with msg.sender
 * - Preserve legacy function (`upgradeTo`, `admin`, `implementation`, `changeAdmin`) for legacy `ProxyAdmin`
 */
contract RoninTransparentProxy is ERC1967Proxy {
  /**
   * @dev The proxy caller is the current admin, and can't fallback to the proxy target. Admin must call via
   * `functionDelegateCall`.
   */
  error ProxyDeniedAdminAccess();

  /**
   * @dev The caller is not the admin.
   */
  error OnlyAdmin();

  receive() external payable {
    _fallback();
  }

  /**
   * @dev Initializes an upgradeable proxy managed by an instance of a {ProxyAdmin} with an `initialOwner`,
   * backed by the implementation at `logic`, and optionally initialized with `data` as explained in
   * {ERC1967Proxy-constructor}.
   */
  constructor(address logic, address admin, bytes memory data) payable ERC1967Proxy(logic, data) {
    // Set the storage value and emit an event for ERC-1967 compatibility
    ERC1967Utils.changeAdmin(admin);
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
    return ERC1967Utils.getAdmin();
  }

  /**
   * @dev If caller is the admin process the call internally, otherwise transparently fallback to the proxy behavior.
   */
  function _fallback() internal virtual override {
    if (msg.sender == _proxyAdmin()) {
      bytes memory ret;

      if (msg.sig == IRoninTransparentProxy.changeAdmin.selector) {
        // Change the admin of the proxy
        ret = _dispatchChangeAdmin();
      } else if (msg.sig == IRoninTransparentProxy.upgradeToAndCall.selector) {
        // Upgrade the implementation of the proxy and call a function
        ret = _dispatchUpgradeToAndCall();
      } else if (msg.sig == IRoninTransparentProxy.upgradeTo.selector) {
        // Upgrade the implementation of the proxy
        ret = _dispatchUpgradeTo();
      } else if (msg.sig == IRoninTransparentProxy.admin.selector) {
        // Get the admin of the proxy
        ret = _dispatchAdmin();
      } else if (msg.sig == IRoninTransparentProxy.implementation.selector) {
        // Get the implementation of the proxy
        ret = _dispatchImplementation();
      } else {
        revert ProxyDeniedAdminAccess();
      }

      assembly ("memory-safe") {
        return(add(ret, 0x20), mload(ret))
      }
    } else {
      super._fallback();
    }
  }

  /**
   * @dev Returns the current implementation.
   *
   * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
   * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
   * `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`
   */
  function _dispatchImplementation() private returns (bytes memory) {
    _requireZeroValue();

    address implementation = _implementation();

    return abi.encode(implementation);
  }

  /**
   * @dev Returns the current admin.
   *
   * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
   * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
   * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
   */
  function _dispatchAdmin() private returns (bytes memory) {
    _requireZeroValue();

    address admin = ERC1967Utils.getAdmin();

    return abi.encode(admin);
  }

  /**
   * @dev Changes the admin of the proxy.
   *
   * Emits an {AdminChanged} event.
   */
  function _dispatchChangeAdmin() private returns (bytes memory ret) {
    _requireZeroValue();

    (address newAdmin) = abi.decode(msg.data[4:], (address));

    ERC1967Utils.changeAdmin(newAdmin);

    return "";
  }

  /**
   * @dev Upgrade the implementation of the proxy. See {ERC1967Utils-upgradeToAndCall}.
   *
   * Requirements:
   *
   * - If `data` is empty, `msg.value` must be zero.
   */
  function _dispatchUpgradeToAndCall() private returns (bytes memory ret) {
    (address newImplementation, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));

    ERC1967Utils.upgradeToAndCall(newImplementation, data);

    return "";
  }

  /**
   * @dev Supports legacy upgradeTo without additional data.
   *
   * Requirements:
   * - `msg.value` must be zero.
   */
  function _dispatchUpgradeTo() private returns (bytes memory ret) {
    (address newImplementation) = abi.decode(msg.data[4:], (address));

    // Already checks for zero value
    ERC1967Utils.upgradeToAndCall(newImplementation, "");

    return "";
  }

  /**
   * @dev To keep this contract fully transparent, all functions for `admin` must be payable. This helper is here to
   * emulate some proxy functions being non-payable while still allowing value to pass through.
   */
  function _requireZeroValue() private {
    if (msg.value != 0) revert ERC1967Utils.ERC1967NonPayable();
  }
}
