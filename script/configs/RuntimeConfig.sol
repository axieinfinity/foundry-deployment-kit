// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "../../lib/forge-std/src/StdStyle.sol";
import { console2 as console } from "../../lib/forge-std/src/console2.sol";
import { LibString } from "../../lib/solady/src/utils/LibString.sol";
import { IRuntimeConfig } from "../interfaces/configs/IRuntimeConfig.sol";

abstract contract RuntimeConfig is IRuntimeConfig {
  using LibString for string;

  bool internal _resolved;
  Option internal _option;
  string internal _rawCommand;

  function getCommand() public view virtual returns (string memory) {
    return _rawCommand;
  }

  function resolveCommand(string calldata command) external virtual {
    if (_resolved) return;

    console.log("command", command);
    if (bytes(command).length != 0) {
      string[] memory args = command.split("@");
      uint256 length = args.length;

      for (uint256 i; i < length;) {
        if (args[i].eq("log")) _option.log = true;
        else if (args[i].eq("trezor")) _option.trezor = true;
        else console.log(StdStyle.yellow("Unsupported command: "), args[i]);

        unchecked {
          ++i;
        }
      }
    }

    _rawCommand = command;
    _resolved = true;

    _handleRuntimeConfig();
  }

  function getRuntimeConfig() public view returns (Option memory option) {
    option = _option;
  }

  function _handleRuntimeConfig() internal virtual;
}
