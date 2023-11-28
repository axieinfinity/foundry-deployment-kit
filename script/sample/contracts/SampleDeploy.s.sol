// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Sample } from "src/Sample.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument, SampleMigration } from "../SampleMigration.s.sol";

contract SampleDeploy is SampleMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.SharedParameter memory param = wrappedConfig.sharedArguments();
    args = abi.encode(param.message);
  }

  function run() public virtual returns (Sample instance) {
    instance = Sample(_deployImmutable(Contract.Sample.key()));
    assertEq(instance.getMessage(), wrappedConfig.sharedArguments().message);
  }
}
