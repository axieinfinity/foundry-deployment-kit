// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { LibString } from "solady/utils/LibString.sol";
import { JSONParserLib } from "solady/utils/JSONParserLib.sol";
import { ILogger } from "./interfaces/ILogger.sol";
import { IGeneralConfig } from "./interfaces/IGeneralConfig.sol";
import { LibSharedAddress } from "./libraries/LibSharedAddress.sol";

contract Logger is ILogger {
  using stdJson for *;
  using StdStyle for *;
  using LibString for *;
  using JSONParserLib for *;

  Vm internal constant vm = Vm(LibSharedAddress.vm);
  IGeneralConfig public constant config = IGeneralConfig(LibSharedAddress.config);

  function generateArtifact(
    address deployer,
    address contractAddr,
    string calldata contractAbsolutePath,
    string calldata fileName,
    bytes calldata args,
    uint256 nonce
  ) external {
    console2.log(
      string.concat(fileName, " deployed at: ", contractAddr.toHexString()).green(),
      string.concat("(nonce: ", nonce.toString(), ")")
    );
    if (!config.getRuntimeConfig().log) {
      console2.log("Skipping artifact generation for:", fileName.yellow());
      return;
    }
    string memory dirPath = config.getDeploymentDirectory(config.getCurrentNetwork());
    string memory filePath = string.concat(dirPath, fileName, ".json");

    string memory json;
    uint256 numDeployments = 1;

    if (vm.exists(filePath)) {
      string memory existedJson = vm.readFile(filePath);
      if (vm.keyExists(existedJson, ".numDeployments")) {
        numDeployments = vm.parseJsonUint(vm.readFile(filePath), ".numDeployments");
        numDeployments += 1;
      }
    }

    json.serialize("args", args);
    json.serialize("nonce", nonce);
    json.serialize("isFoundry", true);
    json.serialize("deployer", deployer);
    json.serialize("chainId", block.chainid);
    json.serialize("address", contractAddr);
    json.serialize("blockNumber", block.number);
    json.serialize("timestamp", block.timestamp);
    json.serialize("contractAbsolutePath", contractAbsolutePath);
    json.serialize("numDeployments", numDeployments);

    string[] memory s = contractAbsolutePath.split(":");
    string memory artifactPath = string.concat("./out/", s[0], s[1].replace(".sol", ""), ".json");
    string memory artifact = vm.readFile(artifactPath);
    JSONParserLib.Item memory item = artifact.parse();

    json.serialize("abi", item.at('"abi"').value());
    json.serialize("ast", item.at('"ast"').value());
    json.serialize("devdoc", item.at('"devdoc"').value());
    json.serialize("userdoc", item.at('"userdoc"').value());
    json.serialize("metadata", item.at('"rawMetadata"').value());
    json.serialize("storageLayout", item.at('"storageLayout"').value());
    json.serialize("bytecode", item.at('"bytecode"').at('"object"').value());
    json = json.serialize("deployedBytecode", item.at('"deployedBytecode"').at('"object"').value());

    json.write(filePath);
  }
}
