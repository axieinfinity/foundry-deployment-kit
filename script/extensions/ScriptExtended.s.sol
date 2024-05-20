// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "../../lib/forge-std/src/StdStyle.sol";
import { console, Script } from "../../lib/forge-std/src/Script.sol";
import { StdAssertions } from "../../lib/forge-std/src/StdAssertions.sol";
import { IVme } from "../interfaces/IVme.sol";
import { IRuntimeConfig } from "../interfaces/configs/IRuntimeConfig.sol";
import { IScriptExtended } from "../interfaces/IScriptExtended.sol";
import { LibErrorHandler } from "../../lib/contract-libs/src/LibErrorHandler.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { TContract } from "../types/TContract.sol";
import { TNetwork } from "../types/TNetwork.sol";
import { logInnerCall, deploySharedAddress } from "../utils/Helpers.sol";
import { BaseScriptExtended } from "./BaseScriptExtended.s.sol";

abstract contract ScriptExtended is BaseScriptExtended, Script, StdAssertions, IScriptExtended {
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
    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(networkType);
    _;
    switchBack(prevNetwork, prevForkId);
  }

  constructor() {
    setUp();
  }

  function setUp() public virtual {
    deploySharedAddress(address(vme), _configByteCode(), "VME");
  }

  function run(bytes calldata callData, string calldata command) public virtual {
    vme.resolveCommand(command);

    IRuntimeConfig.Option memory runtimeConfig = vme.getRuntimeConfig();

    console.log("Current network", network().networkName());
    console.log("Runtime network", runtimeConfig.network.networkName());

    if (runtimeConfig.network != network()) {
      switchTo(runtimeConfig.network, runtimeConfig.forkBlockNumber);
    }

    (bool success, bytes memory data) = address(this).delegatecall(callData);
    success.handleRevert(msg.sig, data);

    if (vme.getRuntimeConfig().disablePostcheck) {
      console.log("\nPostchecking is disabled.".yellow());
      return;
    }

    console.log("\n>> Postchecking...".yellow());
    uint256 start = vm.unixTime();
    vme.setPostCheckingStatus({ status: true });
    _postCheck();
    vme.setPostCheckingStatus({ status: false });
    uint256 end = vm.unixTime();
    console.log("ScriptExtended:".blue(), "Postchecking completed in", vm.toString(end - start), "milliseconds.");
  }

  function _requireOn(TNetwork networkType) private view {
    require(network() == networkType, string.concat("ScriptExtended: Only allowed on ", vme.getAlias(networkType)));
  }

  function deploySharedMigration(TContract contractType, bytes memory bytecode) public returns (address where) {
    where = address(ripemd160(abi.encode(contractType)));
    deploySharedAddress(where, bytecode, string.concat(contractType.contractName(), "Deploy"));
  }

  function switchTo(TNetwork networkType) public virtual returns (TNetwork currNetwork, uint256 currForkId) {
    (currNetwork, currForkId) = switchTo(networkType, 0);
  }

  function switchTo(TNetwork networkType, uint256 forkBlockNumber)
    public
    virtual
    returns (TNetwork prevNetwork, uint256 prevForkId)
  {
    prevForkId = forkId();
    prevNetwork = network();

    vme.createFork(networkType, forkBlockNumber);
    vme.switchTo(networkType, forkBlockNumber);
  }

  function switchBack(TNetwork prevNetwork, uint256 prevForkId) public virtual {
    try vme.switchTo(prevForkId) { }
    catch {
      vme.switchTo(prevNetwork);
    }
  }

  function fail() internal override {
    super.fail();
    revert("ScriptExtended: Got failed assertion");
  }

  function prankOrBroadcast(address to) internal virtual {
    if (vme.isPostChecking()) {
      vm.prank(to);
    } else {
      vm.broadcast(to);
    }
  }

  function _configByteCode() internal virtual returns (bytes memory);

  function _postCheck() internal virtual { }
}
