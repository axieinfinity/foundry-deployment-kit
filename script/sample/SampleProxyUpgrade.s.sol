// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { ScriptExtended } from "../extensions/ScriptExtended.s.sol";
import { SampleProxy } from "src/mocks/SampleProxy.sol";

import { Contract } from "./Contract.sol";

contract SampleProxyUpgrade is ScriptExtended {
  function run() public {
    address proxy = getAddressFromCurrentNetwork(Contract.SampleProxy.key());

    address newLogic = _deployLogic("SampleProxy.sol:SampleProxy");
    _upgradeProxy(proxy, newLogic, abi.encodeCall(SampleProxy.initializeV2, ()));
  }
}
