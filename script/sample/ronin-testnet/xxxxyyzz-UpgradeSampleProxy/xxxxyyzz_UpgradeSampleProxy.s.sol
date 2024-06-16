// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { SampleMigration } from "../../SampleMigration.s.sol";
import { SampleProxy } from "src/mocks/SampleProxy.sol";
import { Contract } from "../../utils/Contract.sol";

contract Migration__XXXXYYZZ_UpgradeSampleProxy is SampleMigration {
  function run() public onlyOn(DefaultNetwork.RoninTestnet.key()) {
    _upgradeProxy(Contract.Sample.key());
  }
}
