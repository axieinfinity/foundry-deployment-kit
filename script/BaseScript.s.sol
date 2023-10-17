// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { LibErrorHandler } from "src/libraries/LibErrorHandler.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { Script, console2 } from "forge-std/Script.sol";
import "./GeneralConfig.s.sol";
import { IScript } from "./interfaces/IScript.sol";
import { IDeployScript } from "./interfaces/IDeployScript.sol";
import { RuntimeConfig } from "./configs/RuntimeConfig.sol";

abstract contract BaseScript is Script, IScript, StdAssertions {
  using LibString for string;
  using StdStyle for string;
  using LibErrorHandler for bool;

  bytes32 public constant GENERAL_CONFIG_SALT = keccak256(bytes(type(GeneralConfig).name));

  Network internal _network;
  GeneralConfig internal _config;

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

  modifier logFn(string memory fnName) {
    console2.log("> ", StdStyle.blue(fnName), "...");
    _;
  }

  function setUp() public virtual {
    // allow diferrent deploy scripts to share same config storage
    // predict general config address
    address cfgAddr = computeCreate2Address(
      GENERAL_CONFIG_SALT, hashInitCode(abi.encodePacked(type(GeneralConfig).creationCode), abi.encode(vm))
    );

    // allow existing on different chain
    vm.makePersistent(cfgAddr);
    vm.allowCheatcodes(cfgAddr);

    // skip if general config already deployed
    if (cfgAddr.code.length == 0) {
      vm.prank(CREATE2_FACTORY);
      new GeneralConfig{ salt: GENERAL_CONFIG_SALT }(vm);
    }

    _config = GeneralConfig(payable(cfgAddr));
    _network = _config.getCurrentNetwork();
  }

  function run(bytes calldata callData, string calldata command) public virtual {
    RuntimeConfig.Options memory options = _parseRuntimeConfig(command);
    _config.setRuntimeConfig(options);

    (bool success, bytes memory returnOrRevertData) = address(this).delegatecall(callData);
    success.handleRevert(returnOrRevertData);
  }

  function _parseRuntimeConfig(string memory command)
    internal
    pure
    virtual
    returns (RuntimeConfig.Options memory options)
  {
    console2.log("command", command);
    if (bytes(command).length != 0) {
      string[] memory args = command.split("@");
      uint256 length = args.length;

      for (uint256 i; i < length;) {
        if (args[i].eq("log")) options.log = true;
        else if (args[i].eq("trezor")) options.trezor = true;
        else console2.log(StdStyle.yellow("Unsupported command: "), args[i]);

        unchecked {
          ++i;
        }
      }
    }
  }

  function fail() internal override {
    super.fail();
    revert("Got failed assertion");
  }
}
