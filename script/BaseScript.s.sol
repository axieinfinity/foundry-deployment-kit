// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import "./GeneralConfig.s.sol";

contract BaseScript is Script, StdAssertions {
  bytes32 public constant GENERAL_CONFIG_SALT = keccak256(bytes(type(GeneralConfig).name));

  GeneralConfig internal _config;
  Network internal _network;

  modifier onMainnet() {
    _network = Network.RoninMainnet;
    _;
  }

  modifier onTestnet() {
    _network = Network.RoninTestnet;
    _;
  }

  modifier onLocalHost() {
    _network = Network.Local;
    _;
  }

  function setUp() public virtual {
    // allow diferrent deploy scripts to share same config storage
    // predict general config address
    address cfgAddr = computeCreate2Address(
      GENERAL_CONFIG_SALT, hashInitCode(abi.encodePacked(type(GeneralConfig).creationCode), abi.encode(vm))
    );
    vm.allowCheatcodes(cfgAddr);
    // skip if general config already deployed
    if (cfgAddr.code.length == 0) {
      vm.prank(CREATE2_FACTORY);
      new GeneralConfig{ salt: GENERAL_CONFIG_SALT }(vm);
    }

    _config = GeneralConfig(payable(cfgAddr));
    _network = _config.getCurrentNetwork();
  }

  function fail() internal override {
    super.fail();
    revert("Got failed assertion");
  }
}
