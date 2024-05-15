// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "../../lib/forge-std/src/StdStyle.sol";
import { Script } from "../../lib/forge-std/src/Script.sol";
import { console } from "../../lib/forge-std/src/Console.sol";
import { StdAssertions } from "../../lib/forge-std/src/StdAssertions.sol";
import { IRuntimeConfig, IGeneralConfig } from "../interfaces/IGeneralConfig.sol";
import { TNetwork, IScriptExtended } from "../interfaces/IScriptExtended.sol";
import { LibErrorHandler } from "../../lib/contract-libs/src/LibErrorHandler.sol";
import { TContract } from "../types/Types.sol";
import { logInnerCall, deploySharedAddress } from "../utils/Utils.sol";
import { vme } from "../utils/Constants.sol";

abstract contract ScriptExtended is Script, StdAssertions, IScriptExtended {
  using StdStyle for *;
  using LibErrorHandler for bool;

  modifier logFn(string memory fnName) {
    logInnerCall(fnName);
    _;
  }

  modifier onlyOn(TNetwork networkType) {
    _requireOn(networkType);
    _;
  }

  modifier onNetwork(TNetwork networkType) {
    (TNetwork currNetwork, uint256 currForkId) = _switchTo(networkType);
    _;
    _switchBack(currNetwork, currForkId);
  }

  constructor() {
    setUp();
  }

  function setUp() public virtual {
    (bytes memory creationCode, bytes memory callData) = _configCreationData();
    deploySharedAddress(address(vme), creationCode, callData, "Vme");
  }

  function _configCreationData() internal virtual returns (bytes memory creationCode, bytes memory callData);

  function _postCheck() internal virtual { }

  function run(bytes calldata callData, string calldata command) public virtual {
    vme.resolveCommand(command);

    IRuntimeConfig.Option memory runtimeConfig = vme.getRuntimeConfig();
    _switchTo(runtimeConfig.network, runtimeConfig.forkBlockNumber);

    (bool success, bytes memory data) = address(this).delegatecall(callData);
    success.handleRevert(msg.sig, data);

    if (vme.getRuntimeConfig().disablePostcheck) {
      console.log("\nPostchecking is disabled.".yellow());
      return;
    }

    console.log("\n>> Postchecking...".yellow());
    vme.setPostCheckingStatus({ status: true });
    _postCheck();
    vme.setPostCheckingStatus({ status: false });
  }

  function network() public view virtual returns (TNetwork) {
    return vme.getCurrentNetwork();
  }

  function forkId() public view virtual returns (uint256) {
    try vm.activeFork() returns (uint256 id) {
      return id;
    } catch {
      return vme.getForkId(network());
    }
  }

  function sender() public view virtual returns (address payable) {
    return vme.getSender();
  }

  function fail() internal override {
    super.fail();
    revert("ScriptExtended: Got failed assertion");
  }

  function deploySharedMigration(TContract contractType, bytes memory bytecode) public returns (address where) {
    where = address(ripemd160(abi.encode(contractType)));
    deploySharedAddress(where, bytecode, string.concat(contractType.contractName(), "Deploy"));
  }

  function _requireOn(TNetwork networkType) private view {
    require(
      network() == networkType,
      string.concat("ScriptExtended: Only allowed on ", vme.getAlias(networkType), " Got: ", vme.getAlias(network()))
    );
  }

  function _switchTo(TNetwork networkType) private returns (TNetwork currNetwork, uint256 currForkId) {
    (currNetwork, currForkId) = _switchTo(networkType, 0);
  }

  function _switchTo(TNetwork networkType, uint256 forkBlockNumber)
    internal
    returns (TNetwork currNetwork, uint256 currForkId)
  {
    currForkId = forkId();
    currNetwork = network();

    vme.createFork(networkType, forkBlockNumber);
    vme.switchTo(networkType, forkBlockNumber);
  }

  function _switchBack(TNetwork prevNetwork, uint256 prevForkId) internal {
    try vme.switchTo(prevForkId) { }
    catch {
      vme.switchTo(prevNetwork);
    }
  }
}
