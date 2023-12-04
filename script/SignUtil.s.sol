// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { LibSig } from "./libraries/LibSig.sol";
import { Script } from "../lib/forge-std/src/Script.sol";
import { LibString } from "../lib/solady/src/utils/LibString.sol";
import { BaseGeneralConfig } from "./BaseGeneralConfig.sol";
import { console, BaseMigration } from "./BaseMigration.s.sol";

contract SignUtil is Script {
  function run() external {
    uint256 pk = vm.envUint("TESTNET_PK");
    console.log("sender", vm.rememberKey(vm.envUint("TESTNET_PK")));

    string memory signData = "hello";
    bytes32 digest = ECDSA.toEthSignedMessageHash(bytes(signData));

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
    bytes memory vmSig = LibSig.merge(v, r, s);

    string[] memory commandInput = new string[](6);
    commandInput[0] = "cast";
    commandInput[1] = "wallet";
    commandInput[2] = "sign";
    commandInput[3] = "--private-key";
    commandInput[4] = LibString.toHexString(pk);
    commandInput[5] = signData;
    bytes memory castSig = vm.ffi(commandInput);

    console.log("pk", LibString.toHexString(pk));
    console.log("vmSig", vm.toString(vmSig));
    console.log("castSig", vm.toString(castSig));
  }
}
