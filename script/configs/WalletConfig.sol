// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { CommonBase } from "../../lib/forge-std/src/Base.sol";
import { LibString } from "../../lib/solady/src/utils/LibString.sol";
import { IWalletConfig } from "../interfaces/configs/IWalletConfig.sol";

abstract contract WalletConfig is CommonBase, IWalletConfig {
  using LibString for string;

  string internal _envLabel;
  address internal _envSender;
  address internal _trezorSender;
  WalletOption internal _walletOption;

  function getSender() public view virtual returns (address payable sender);

  function trezorPrefix() public view virtual returns (string memory) {
    return "trezor://";
  }

  function deployerEnvLabel() public view virtual returns (string memory) {
    return "DEPLOYER";
  }

  function ethSignMessage(address by, string memory message, WalletOption walletOption)
    public
    returns (bytes memory sig)
  {
    sig =
      walletOption == WalletOption.Env ? envEthSignMessage(by, message, _envLabel) : trezorEthSignMessage(by, message);
  }

  function ethSignMessage(string memory message) public returns (bytes memory sig) {
    sig = _walletOption == WalletOption.Env
      ? envEthSignMessage(_envSender, message, _envLabel)
      : trezorEthSignMessage(_trezorSender, message);
  }

  function envEthSignMessage(address by, string memory message, string memory envLabel)
    public
    returns (bytes memory sig)
  {
    sig = ethSignMessage(by, message, _loadENVPrivateKey(envLabel));
  }

  function ethSignMessage(address by, string memory message, uint256 privateKey) public returns (bytes memory sig) {
    string[] memory commandInput = new string[](8);
    commandInput[0] = "cast";
    commandInput[1] = "wallet";
    commandInput[2] = "sign";
    commandInput[3] = "--from";
    commandInput[4] = vm.toString(by);
    commandInput[5] = "--private-key";
    commandInput[6] = LibString.toHexString(privateKey);
    commandInput[7] = message;

    sig = vm.ffi(commandInput);
  }

  function trezorEthSignMessage(address by, string memory message) public returns (bytes memory sig) {
    string[] memory commandInput = new string[](7);
    commandInput[0] = "cast";
    commandInput[1] = "wallet";
    commandInput[2] = "sign";
    commandInput[3] = "--from";
    commandInput[4] = vm.toString(by);
    commandInput[5] = "--trezor";
    commandInput[6] = message;

    sig = vm.ffi(commandInput);
  }

  function signTypedDataV4(address by, string memory filePath, WalletOption walletOption)
    public
    returns (bytes memory sig)
  {
    sig = walletOption == WalletOption.Env
      ? envSignTypedDataV4(by, filePath, _envLabel)
      : trezorSignTypedDataV4(by, filePath);
  }

  function signTypedDataV4(string memory filePath) public returns (bytes memory sig) {
    sig = _walletOption == WalletOption.Env
      ? envSignTypedDataV4(_envSender, filePath, _envLabel)
      : trezorSignTypedDataV4(_trezorSender, filePath);
  }

  function envSignTypedDataV4(address by, string memory filePath, string memory envLabel)
    public
    returns (bytes memory sig)
  {
    sig = signTypedDataV4(by, filePath, _loadENVPrivateKey(envLabel));
  }

  function signTypedDataV4(address by, string memory filePath, uint256 privateKey) public returns (bytes memory sig) {
    string[] memory commandInput = new string[](10);
    commandInput[0] = "cast";
    commandInput[1] = "wallet";
    commandInput[2] = "sign";
    commandInput[3] = "--from";
    commandInput[4] = vm.toString(by);
    commandInput[5] = "--private-key";
    commandInput[6] = LibString.toHexString(privateKey);
    commandInput[7] = "--data";
    commandInput[8] = "--from-file";
    commandInput[9] = filePath;

    sig = vm.ffi(commandInput);
  }

  function trezorSignTypedDataV4(address by, string memory filePath) public returns (bytes memory sig) {
    string[] memory commandInput = new string[](9);
    commandInput[0] = "cast";
    commandInput[1] = "wallet";
    commandInput[2] = "sign";
    commandInput[3] = "--from";
    commandInput[4] = vm.toString(by);
    commandInput[5] = "--trezor";
    commandInput[6] = "--data";
    commandInput[7] = "--from-file";
    commandInput[8] = filePath;

    sig = vm.ffi(commandInput);
  }

  function _loadTrezorAccount() internal {
    if (tx.origin != DEFAULT_SENDER) {
      _trezorSender = tx.origin;
    } else {
      try vm.envString(deployerEnvLabel()) returns (string memory str) {
        _trezorSender = vm.parseAddress(str.replace(trezorPrefix(), ""));
      } catch {
        revert(
          string.concat(
            "\nGeneralConfig: Error finding trezor address!\n- Please override default sender with `--sender {your_trezor_account}` tag \n- Or make `.env` file and create field `",
            deployerEnvLabel(),
            "=",
            trezorPrefix(),
            "{your_trezor_account}`"
          )
        );
      }
    }
    _walletOption = WalletOption.Trezor;
  }

  function _loadENVAccount(string memory envLabel) internal {
    _envLabel = envLabel;
    _walletOption = WalletOption.Env;
    _envSender = vm.rememberKey(_loadENVPrivateKey(envLabel));
  }

  function _loadENVPrivateKey(string memory envLabel) private view returns (uint256) {
    try vm.envUint(envLabel) returns (uint256 pk) {
      return pk;
    } catch {
      revert(
        string.concat(
          "\nGeneralConfig: Error finding env address!\n- Please make `.env` file and create field `",
          envLabel,
          "=",
          "{op_secret_reference_or_your_private_key}`"
        )
      );
    }
  }
}
