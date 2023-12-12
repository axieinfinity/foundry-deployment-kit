// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { ISharedArgument, SampleMigration } from "../../SampleMigration.s.sol";
import { Sample, SampleDeploy } from "../../contracts/SampleDeploy.s.sol";
import { SampleProxy, SampleProxyDeploy } from "../../contracts/SampleProxyDeploy.s.sol";

contract Migration__XXXXYYZZ_DeploySample is SampleMigration {
  function _sharedArguments() internal virtual override returns (bytes memory args) {
    args = super._sharedArguments();

    ISharedArgument.SharedParameter memory param = abi.decode(args, (ISharedArgument.SharedParameter));
    param.message = "Migration__XXXXYYZZ_DeploySample@TestnetSample";
    param.proxyMessage = "Migration__XXXXYYZZ_DeploySample@TestnetProxySample";

    args = abi.encode(param);
  }

  function run() public onlyOn(DefaultNetwork.RoninTestnet.key()) {
    Sample sample = new SampleDeploy().run();
    SampleProxy sampleProxy = new SampleProxyDeploy().run();

    assertEq(sample.getMessage(), "Migration__XXXXYYZZ_DeploySample@TestnetSample");
    assertEq(sampleProxy.getMessage(), "Migration__XXXXYYZZ_DeploySample@TestnetProxySample");
  }
}
