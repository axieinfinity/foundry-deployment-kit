// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { Sample } from "src/mocks/Sample.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument, SampleMigration } from "../SampleMigration.s.sol";

contract SampleDeploy is SampleMigration {
  function run() public virtual returns (Sample instance) {
    instance = Sample(_deployImmutable(Contract.Sample.key()));
  }
}
