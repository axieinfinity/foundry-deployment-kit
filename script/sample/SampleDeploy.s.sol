// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { ScriptExtended } from "../extensions/ScriptExtended.s.sol";
import { Sample } from "src/mocks/Sample.sol";

import { Contract } from "./Contract.sol";

contract SampleDeploy is ScriptExtended {
  function run() public {
    Sample sample = Sample(_deployFromArtifact("Sample.sol:Sample"));
    sample.setMessage("hello");

    recordDeployment(Contract.Sample.key(), address(sample), _deploymentRoot);
  }
}
