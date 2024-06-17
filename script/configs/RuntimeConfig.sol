// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { Vm } from "../../dependencies/forge-std-1.8.2/src/Vm.sol";
import { StdStyle } from "../../dependencies/forge-std-1.8.2/src/StdStyle.sol";
import { console } from "../../dependencies/forge-std-1.8.2/src/console.sol";
import { LibString } from "../../dependencies/solady-0.0.206/src/utils/LibString.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { IRuntimeConfig } from "../interfaces/configs/IRuntimeConfig.sol";
import { TNetwork } from "../types/Types.sol";
import { DefaultNetwork } from "../utils/DefaultNetwork.sol";

abstract contract RuntimeConfig is IRuntimeConfig {
  using LibString for string;

  Vm private constant vm = Vm(LibSharedAddress.VM);

  bool internal _resolved;
  Option internal _option;
  string internal _rawCommand;
  bool internal _isPostChecking;
  bool internal _isPreChecking;

  function getCommand() public view virtual returns (string memory) {
    return _rawCommand;
  }

  function isPostChecking() public view virtual returns (bool) {
    return _isPostChecking;
  }

  function setPostCheckingStatus(bool status) public virtual {
    _isPostChecking = status;
  }

  function isPreChecking() public view virtual returns (bool) {
    return _isPreChecking;
  }

  function setPreCheckingStatus(bool status) public virtual {
    _isPreChecking = status;
  }

  function resolveCommand(string calldata command) external virtual {
    if (_resolved) return;

    _option.network = DefaultNetwork.LocalHost.key();

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
        } else if (args[i].eq("no-precheck")) {
          _option.disablePrecheck = true;
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
