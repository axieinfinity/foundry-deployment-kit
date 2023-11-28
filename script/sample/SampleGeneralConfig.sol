// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseGeneralConfig } from "foundry-deployment-kit/BaseGeneralConfig.sol";
import { Contract } from "./utils/Contract.sol";

contract SampleGeneralConfig is BaseGeneralConfig {
  constructor() BaseGeneralConfig("", "deployments/") { }

  function _setUpContracts() internal virtual override {
    super._setUpContracts();

    _contractNameMap[Contract.Sample.key()] = Contract.Sample.name();
    _contractNameMap[Contract.SampleProxy.key()] = Contract.SampleProxy.name();
  }
}
