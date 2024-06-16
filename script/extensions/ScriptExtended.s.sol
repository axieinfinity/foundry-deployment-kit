// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { VmSafe } from "../../dependencies/forge-std-1.8.2/src/Vm.sol";
import { StdStyle } from "../../dependencies/forge-std-1.8.2/src/StdStyle.sol";
import { console, Script } from "../../dependencies/forge-std-1.8.2/src/Script.sol";
import { StdAssertions } from "../../dependencies/forge-std-1.8.2/src/StdAssertions.sol";
import { IVme } from "../interfaces/IVme.sol";
import { IRuntimeConfig } from "../interfaces/configs/IRuntimeConfig.sol";
import { IScriptExtended } from "../interfaces/IScriptExtended.sol";
import { LibErrorHandler } from "../libraries/LibErrorHandler.sol";
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
    try vm.isContext(VmSafe.ForgeContext.Test) {
      setUp();
    } catch {
      // Do nothing
    }
  }

  function setUp() public virtual {
    deploySharedAddress(address(vme), _configByteCode(), "VME");
  }

  function run(bytes calldata callData, string calldata command) public virtual {
    vme.resolveCommand(command);

    IRuntimeConfig.Option memory runtimeConfig = vme.getRuntimeConfig();

    if (runtimeConfig.network != network()) {
      switchTo(runtimeConfig.network, runtimeConfig.forkBlockNumber);
    } else {
      uint256 currUnixTimestamp = vm.unixTime() / 1_000;
      if (vm.getBlockTimestamp() < currUnixTimestamp) vm.warp(currUnixTimestamp);
      if (runtimeConfig.forkBlockNumber != 0) vme.rollUpTo(runtimeConfig.forkBlockNumber);

      vme.logSenderInfo();
      vme.setUpDefaultContracts();
      vme.logCurrentForkInfo();
    }

    uint256 start;
    uint256 end;

    if (runtimeConfig.disablePrecheck) {
      console.log("\nPrechecking is disabled.".yellow());
    } else {
      console.log("\n>> Prechecking...".yellow());
      vme.setPreCheckingStatus({ status: true });
      start = vm.unixTime();
      _preCheck();
      end = vm.unixTime();
      vme.setPreCheckingStatus({ status: false });
      console.log("ScriptExtended:".blue(), "Prechecking completed in", vm.toString(end - start), "milliseconds.\n");
    }

    (bool success, bytes memory data) = address(this).delegatecall(callData);
    success.handleRevert(msg.sig, data);

    if (vme.getRuntimeConfig().disablePostcheck) {
      console.log("\nPostchecking is disabled.".yellow());
    } else {
      console.log("\n>> Postchecking...".yellow());
      vme.setPostCheckingStatus({ status: true });
      start = vm.unixTime();
      _postCheck();
      end = vm.unixTime();
      vme.setPostCheckingStatus({ status: false });
      console.log("ScriptExtended:".blue(), "Postchecking completed in", vm.toString(end - start), "milliseconds.");
    }
  }

  function _requireOn(TNetwork networkType) private view {
    require(network() == networkType, string.concat("ScriptExtended: Only allowed on ", vme.getAlias(networkType)));
  }

  function deploySharedMigration(TContract contractType, bytes memory bytecode) public returns (address where) {
    where = address(ripemd160(abi.encode(contractType)));
    deploySharedAddress(where, bytecode, string.concat(contractType.name(), "Deploy"));
  }

  function switchTo(TNetwork networkType) public virtual returns (TNetwork currNetwork, uint256 currForkId) {
    (currNetwork, currForkId) = switchTo({ networkType: networkType, forkBlockNumber: 0 });
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

  function prankOrBroadcast(address by) internal virtual {
    if (vme.isPostChecking()) {
      vm.prank(by);
    } else {
      vm.broadcast(by);
    }
  }

  function _configByteCode() internal virtual returns (bytes memory);

  function _postCheck() internal virtual { }

  function _preCheck() internal virtual { }
}
