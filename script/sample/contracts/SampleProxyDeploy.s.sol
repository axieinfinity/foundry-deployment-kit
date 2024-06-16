// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { SampleProxy } from "src/mocks/SampleProxy.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument, SampleMigration } from "../SampleMigration.s.sol";

contract SampleProxyDeploy is SampleMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.SharedParameter memory param = ISharedArgument(address(vme)).sharedArguments();
    args = abi.encodeCall(SampleProxy.initialize, (param.proxyMessage));
  }

  function run() public virtual returns (SampleProxy instance) {
    instance = SampleProxy(_deployProxy(Contract.SampleProxy.key()));
    assertEq(instance.getMessage(), ISharedArgument(address(vme)).sharedArguments().proxyMessage);
  }
}
