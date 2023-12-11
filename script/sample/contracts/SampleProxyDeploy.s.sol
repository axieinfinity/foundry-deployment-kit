// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SampleProxy } from "src/SampleProxy.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument, SampleMigration } from "../SampleMigration.s.sol";

contract SampleProxyDeploy is SampleMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.SharedParameter memory param = ISharedArgument(address(CONFIG)).sharedArguments();
    args = abi.encodeCall(SampleProxy.initialize, (param.proxyMessage));
  }

  function run() public virtual returns (SampleProxy instance) {
    instance = SampleProxy(_deployProxy(Contract.SampleProxy.key()));
    assertEq(instance.getMessage(), ISharedArgument(address(CONFIG)).sharedArguments().proxyMessage);
  }
}
