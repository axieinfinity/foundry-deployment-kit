// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { SampleGeneralConfig } from "./SampleGeneralConfig.sol";
import { ISharedArgument } from "./interfaces/ISharedArgument.sol";

contract SampleMigration is BaseMigration {
  ISharedArgument public constant config = ISharedArgument(address(vme));

  function _configCreationData() internal virtual override returns (bytes memory creationCode, bytes memory callData) {
    creationCode = abi.encodePacked(type(SampleGeneralConfig).creationCode);
    callData = abi.encodeCall(SampleGeneralConfig.initialize, ());
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
