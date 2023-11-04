// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IWalletConfig } from "../interfaces/configs/IWalletConfig.sol";

abstract contract WalletConfig is IWalletConfig {
  /// @dev Trezor deployer address
  string public constant TREZOR_PREFIX = "trezor://";
  string public constant DEPLOYER_ENV_LABEL = "DEPLOYER";

  address internal _envSender;
  address internal _trezorSender;

  function getSender() public view virtual returns (address payable sender);
}
