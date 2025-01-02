// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { console } from "../dependencies/forge-std-1.9.5/src/console.sol";

import "script/sample/SampleGeneralConfig.sol";

contract MockConfig is SampleGeneralConfig {
  function updateSampleProxyLogicForTesting(
    string memory contractName
  ) public {
    console.log("Cheating contract logic for testing...");
    _contractNameMap[Contract.SampleProxy.key()] = contractName;
  }
}
