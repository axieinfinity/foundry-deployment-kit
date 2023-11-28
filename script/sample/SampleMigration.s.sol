// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { SampleGeneralConfig } from "./SampleGeneralConfig.sol";
import { ISharedArgument } from "./interfaces/ISharedArgument.sol";

contract SampleMigration is BaseMigration {
  ISharedArgument public constant wrappedConfig = ISharedArgument(address(CONFIG));

  function _configByteCode() internal virtual override returns (bytes memory) {
    return abi.encodePacked(type(SampleGeneralConfig).creationCode);
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawArgs) {
    ISharedArgument.SharedParameter memory param;

    if (network() == DefaultNetwork.RoninTestnet.key()) {
      param.message = "Sample Ronin Testnet";
      param.proxyMessage = "Sample Proxy Ronin Testnet";
    }
    if (network() == DefaultNetwork.RoninMainnet.key()) {
      param.message = "Sample Ronin Mainnet";
      param.proxyMessage = "Sample Proxy Ronin Mainnet";
    }
    if (network() == DefaultNetwork.Local.key()) {
      param.message = "Sample Anvil";
      param.proxyMessage = "Sample Proxy Anvil";
    }

    rawArgs = abi.encode(param);
  }
}
