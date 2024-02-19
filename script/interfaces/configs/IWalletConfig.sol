// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IWalletConfig {
  enum WalletOption {
    Env,
    Trezor
  }

  function getSender() external view returns (address payable sender);

  function trezorPrefix() external view returns (string memory);

  function deployerEnvLabel() external view returns (string memory);

  function ethSignMessage(address by, string memory message, WalletOption walletOption)
    external
    returns (bytes memory sig);

  function ethSignMessage(string memory message) external returns (bytes memory sig);

  function ethSignMessage(address by, string memory message, uint256 privateKey) external returns (bytes memory sig);

  function envEthSignMessage(address by, string memory message, string memory envLabel)
    external
    returns (bytes memory sig);

  function envSignTypedDataV4(address by, string memory filePath, string memory envLabel)
    external
    returns (bytes memory sig);

  function trezorEthSignMessage(address by, string memory message) external returns (bytes memory sig);

  function trezorSignTypedDataV4(address by, string memory filePath) external returns (bytes memory sig);

  function signTypedDataV4(address by, string memory filePath, uint256 privateKey) external returns (bytes memory sig);

  function signTypedDataV4(address by, string memory filePath, WalletOption walletOption)
    external
    returns (bytes memory sig);

  function signTypedDataV4(string memory filePath) external returns (bytes memory sig);
}
