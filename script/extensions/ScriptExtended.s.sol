// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "../../lib/forge-std/src/StdStyle.sol";
import { console, Script } from "../../lib/forge-std/src/Script.sol";
import { StdAssertions } from "../../lib/forge-std/src/StdAssertions.sol";
import { IGeneralConfig } from "../interfaces/IGeneralConfig.sol";
import { TNetwork, IScriptExtended } from "../interfaces/IScriptExtended.sol";
import { LibErrorHandler } from "../../lib/contract-libs/src/LibErrorHandler.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { TContract } from "../types/Types.sol";

abstract contract ScriptExtended is Script, StdAssertions, IScriptExtended {
  using LibErrorHandler for bool;

  bytes public constant EMPTY_ARGS = "";
  IGeneralConfig public constant CONFIG = IGeneralConfig(LibSharedAddress.CONFIG);
  bool internal _isPostChecking;

  modifier logFn(string memory fnName) {
    _logFn(fnName);
    _;
  }

  modifier onlyOn(TNetwork networkType) {
    _requireOn(networkType);
    _;
  }

  modifier onNetwork(TNetwork networkType) {
    TNetwork currentNetwork = _switchTo(networkType);
    _;
    _switchBack(currentNetwork);
  }

  constructor() {
    setUp();
  }

  function setUp() public virtual {
    deploySharedAddress(address(CONFIG), _configByteCode(), "GeneralConfig");
  }

  function _configByteCode() internal virtual returns (bytes memory);

  function _postCheck() internal virtual { }

  function run(bytes calldata callData, string calldata command) public virtual {
    CONFIG.resolveCommand(command);
    (bool success, bytes memory data) = address(this).delegatecall(callData);
    success.handleRevert(msg.sig, data);

    CONFIG.setPostCheckingStatus({ status: true });
    _postCheck();
    CONFIG.setPostCheckingStatus({ status: false });
  }

  function network() public view virtual returns (TNetwork) {
    return CONFIG.getCurrentNetwork();
  }

  function forkId() public view virtual returns (uint256) {
    return CONFIG.getForkId(network());
  }

  function sender() public view virtual returns (address payable) {
    return CONFIG.getSender();
  }

  function fail() internal override {
    super.fail();
    revert("ScriptExtended: Got failed assertion");
  }

  function deploySharedAddress(address where, bytes memory bytecode, string memory label) public {
    if (where.code.length == 0) {
      vm.makePersistent(where);
      vm.allowCheatcodes(where);
      deployCodeTo(bytecode, where);
      if (bytes(label).length != 0) vm.label(where, label);
    }
  }

  function deploySharedMigration(TContract contractType, bytes memory bytecode) public returns (address where) {
    where = address(ripemd160(abi.encode(contractType)));
    deploySharedAddress(where, bytecode, string.concat(contractType.contractName(), "Deploy"));
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

  function _logFn(string memory fnName) private view {
    console.log("> ", StdStyle.blue(fnName), "...");
  }

  function _requireOn(TNetwork networkType) private view {
    require(network() == networkType, string.concat("ScriptExtended: Only allowed on ", CONFIG.getAlias(networkType)));
  }

  function _switchTo(TNetwork networkType) private returns (TNetwork currentNetwork) {
    currentNetwork = network();
    CONFIG.createFork(networkType);
    CONFIG.switchTo(networkType);
  }

  function _switchBack(TNetwork currentNetwork) private {
    CONFIG.switchTo(currentNetwork);
  }
}
