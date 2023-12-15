// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IWalletConfig {
  function getSenderPk() external view returns (uint256);

  function getSender() external view returns (address payable sender);

  function trezorPrefix() external view returns (string memory);

  function deployerEnvLabel() external view returns (string memory);
}
