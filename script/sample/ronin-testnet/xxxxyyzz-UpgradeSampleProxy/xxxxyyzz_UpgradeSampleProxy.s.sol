// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { SampleMigration } from "../../SampleMigration.s.sol";
import { SampleProxy } from "src/mocks/SampleProxy.sol";
import { Contract } from "../../utils/Contract.sol";

contract Migration__XXXXYYZZ_UpgradeSampleProxy is SampleMigration {
  function run() public onlyOn(DefaultNetwork.RoninTestnet.key()) {
    _upgradeProxy(Contract.Sample.key());
  }
}
