// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IWalletConfig } from "../interfaces/configs/IWalletConfig.sol";

abstract contract WalletConfig is IWalletConfig {
  uint256 internal _envPk;
  address internal _envSender;
  address internal _trezorSender;

  function getSender() public view virtual returns (address payable sender);

  function trezorPrefix() public view virtual returns (string memory) {
    return "trezor://";
  }

  function deployerEnvLabel() public view virtual returns (string memory) {
    return "DEPLOYER";
  }
}
