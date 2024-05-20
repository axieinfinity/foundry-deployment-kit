// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Sample } from "src/mocks/Sample.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument, SampleMigration } from "../SampleMigration.s.sol";

contract SampleDeploy is SampleMigration {
  function run() public virtual returns (Sample instance) {
    instance = Sample(_deployImmutable(Contract.Sample.key()));
    assertEq(instance.getMessage(), config.sharedArguments().message);
  }
}
