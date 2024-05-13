// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseGeneralConfig } from "@fdk/BaseGeneralConfig.sol";
import { Contract } from "./utils/Contract.sol";

contract SampleGeneralConfig is BaseGeneralConfig {
  function initialize() external virtual override {
    __BaseGeneralConfig_init("", "deployments/");
  }

  function _setUpContracts() internal virtual override {
    _contractNameMap[Contract.Sample.key()] = Contract.Sample.name();
    // {SampleClone} share same logic as {Sample}
    _contractNameMap[Contract.SampleClone.key()] = Contract.Sample.name();
    _contractNameMap[Contract.SampleProxy.key()] = Contract.SampleProxy.name();

    // allow different contracts to share same logic
    _contractNameMap[Contract.tSLP.key()] = "Token";
    _contractNameMap[Contract.tAXS.key()] = "Token";
    _contractNameMap[Contract.tWETH.key()] = "Token";
    _contractNameMap[Contract.tWRON.key()] = "Token";
    _contractNameMap[Contract.tBERRY.key()] = "Token";
  }
}
