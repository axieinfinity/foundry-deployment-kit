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

  function _loadENVPrivateKey(string memory envLabel) private returns (uint256) {
    try vm.envUint(envLabel) returns (uint256 pk) {
      return pk;
    } catch {
      string[] memory commandInput = new string[](3);

      try vm.envString(envLabel) returns (string memory data) {
        commandInput[2] = data;
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
      commandInput[0] = "op";
      commandInput[1] = "read";

      return vm.parseUint(vm.toString(vm.ffi(commandInput)));
    }
  }
}
