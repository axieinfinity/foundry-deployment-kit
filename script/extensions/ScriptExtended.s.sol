// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "lib/forge-std/src/StdStyle.sol";
import { console, Script } from "lib/forge-std/src/Script.sol";
import { StdAssertions } from "lib/forge-std/src/StdAssertions.sol";
import { IGeneralConfig } from "../interfaces/IGeneralConfig.sol";
import { IScriptExtended } from "../interfaces/IScriptExtended.sol";
import { LibErrorHandler } from "../libraries/LibErrorHandler.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { TNetwork } from "../types/Types.sol";

abstract contract ScriptExtended is Script, StdAssertions, IScriptExtended {
  using LibErrorHandler for bool;

  bytes public constant EMPTY_ARGS = "";
  IGeneralConfig public constant CONFIG = IGeneralConfig(LibSharedAddress.CONFIG);

  modifier logFn(string memory fnName) {
    console.log("> ", StdStyle.blue(fnName), "...");
    _;
  }

  modifier prankAs(address from) {
    vm.startPrank(from);
    _;
    vm.stopPrank();
  }

  modifier broadcastAs(address from) {
    vm.startBroadcast(from);
    vm.resumeGasMetering();
    _;
    vm.pauseGasMetering();
    vm.stopBroadcast();
  }

  function setUp() public virtual {
    vm.pauseGasMetering();
    vm.label(address(CONFIG), "GeneralConfig");
    deploySharedAddress(address(CONFIG), _configByteCode());
  }

  function _configByteCode() internal virtual returns (bytes memory);

  function run(bytes calldata callData, string calldata command) public virtual {
    CONFIG.resolveCommand(command);
    (bool success, bytes memory data) = address(this).delegatecall(callData);
    success.handleRevert(data);
  }

  function network() public view virtual returns (TNetwork) {
    return CONFIG.getCurrentNetwork();
  }

  function sender() public view virtual returns (address payable) {
    return CONFIG.getSender();
  }

  function fail() internal override {
    super.fail();
    revert("Got failed assertion");
  }

  function deploySharedAddress(address where, bytes memory bytecode) public {
    if (where.code.length == 0) {
      vm.makePersistent(where);
      vm.allowCheatcodes(where);
      deployCodeTo(bytecode, where);
    }
  }

  function deployCodeTo(bytes memory creationCode, address where) internal {
    deployCodeTo(EMPTY_ARGS, creationCode, 0, where);
  }

  function deployCodeTo(bytes memory creationCode, uint256 value, address where) internal {
    deployCodeTo(EMPTY_ARGS, creationCode, value, where);
  }

  function deployCodeTo(bytes memory args, bytes memory creationCode, uint256 value, address where) internal {
    vm.etch(where, abi.encodePacked(creationCode, args));
    (bool success, bytes memory runtimeBytecode) = where.call{ value: value }("");
    assertTrue(success, "ScriptExtended: Failed to create runtime bytecode.");
    vm.etch(where, runtimeBytecode);
  }
}
