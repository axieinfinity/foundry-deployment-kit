// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { ISharedArgument, SampleMigration } from "../../SampleMigration.s.sol";
import { Sample, SampleDeploy } from "../../contracts/SampleDeploy.s.sol";
import { SampleProxy, SampleProxyDeploy } from "../../contracts/SampleProxyDeploy.s.sol";

contract Migration__XXXXYYZZ_DeploySample is SampleMigration {
  function _sharedArguments() internal virtual override returns (bytes memory args) {
    args = super._sharedArguments();

    ISharedArgument.SharedParameter memory param = abi.decode(args, (ISharedArgument.SharedParameter));
    param.message = "Migration__XXXXYYZZ_DeploySample@MainnetSample";
    param.proxyMessage = "Migration__XXXXYYZZ_DeploySample@MainnetProxySample";

    args = abi.encode(param);
  }

  function run() public onlyOn(DefaultNetwork.RoninMainnet.key()) {
    Sample sample = new SampleDeploy().run();
    SampleProxy sampleProxy = new SampleProxyDeploy().run();

    assertEq(sample.getMessage(), "Migration__XXXXYYZZ_DeploySample@MainnetSample");
    assertEq(sampleProxy.getMessage(), "Migration__XXXXYYZZ_DeploySample@MainnetProxySample");
  }
}
