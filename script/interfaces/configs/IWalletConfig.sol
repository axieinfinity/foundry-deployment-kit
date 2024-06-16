// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

interface IWalletConfig {
  enum WalletOption {
    Env,
    Trezor
  }

  function loadTrezorAccount() external;

  function loadENVAccount(string calldata envLabel) external;

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
