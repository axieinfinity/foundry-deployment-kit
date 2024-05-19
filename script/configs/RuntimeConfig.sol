// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "../../lib/forge-std/src/Vm.sol";
import { StdStyle } from "../../lib/forge-std/src/StdStyle.sol";
import { console } from "../../lib/forge-std/src/console.sol";
import { LibString } from "../../lib/solady/src/utils/LibString.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { IRuntimeConfig } from "../interfaces/configs/IRuntimeConfig.sol";
import { TNetwork } from "../types/Types.sol";

abstract contract RuntimeConfig is IRuntimeConfig {
  using LibString for string;

  Vm private constant vm = Vm(LibSharedAddress.VM);

  bool internal _resolved;
  Option internal _option;
  string internal _rawCommand;
  bool internal _isPostChecking;

  function getCommand() public view virtual returns (string memory) {
    return _rawCommand;
  }

  function isPostChecking() public view virtual returns (bool) {
    return _isPostChecking;
  }

  function setPostCheckingStatus(bool status) public virtual {
    _isPostChecking = status;
  }

  function resolveCommand(string calldata command) external virtual {
    if (_resolved) return;
    if (bytes(command).length != 0) {
      string[] memory args = command.split("@");
      uint256 length = args.length;

      for (uint256 i; i < length; ++i) {
        if (args[i].eq("generate-artifact")) {
          _option.generateArtifact = true;
        } else if (args[i].eq("trezor")) {
          _option.trezor = true;
        } else if (args[i].eq("no-postcheck")) {
          _option.disablePostcheck = true;
        } else if (args[i].startsWith("network")) {
          string memory network = vm.split(args[i], ".")[1];
          _option.network = TNetwork.wrap(LibString.packOne(network));
        } else if (args[i].startsWith("fork-block-number")) {
          string memory blockNumber = vm.split(args[i], ".")[1];
          _option.forkBlockNumber = vm.parseUint(blockNumber);
        } else if (args[i].startsWith("sender")) {
          string memory sender = vm.split(args[i], ".")[1];
          _option.sender = vm.parseAddress(sender);
        } else {
          console.log("Invalid command: %s", args[i]);
        }
      }
    }

    _rawCommand = command;
    _resolved = true;

    buildRuntimeConfig();
  }

  function getRuntimeConfig() public view returns (Option memory option) {
    option = _option;
  }

  function buildRuntimeConfig() public virtual;
}
