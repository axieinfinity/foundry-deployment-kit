// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { ScriptExtended } from "../extensions/ScriptExtended.s.sol";
import { SampleProxy } from "src/mocks/SampleProxy.sol";

import { Contract } from "./Contract.sol";

contract SampleProxyDeploy is ScriptExtended {
  function run() public {
    address proxyAdmin = vm.envAddress("PROXY_ADMIN");
    bytes memory initData = abi.encodeCall(SampleProxy.initialize, ("hello"));

    address proxy = _deployTransparentProxy("SampleProxy.sol:SampleProxy", proxyAdmin, initData);

    recordDeployment(Contract.SampleProxy.key(), proxy, _deploymentRoot);
  }
}
