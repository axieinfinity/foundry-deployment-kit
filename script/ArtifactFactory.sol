// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "../lib/forge-std/src/Vm.sol";
import { stdJson } from "../lib/forge-std/src/StdJson.sol";
import { StdStyle } from "../lib/forge-std/src/StdStyle.sol";
import { console } from "../lib/forge-std/src/console.sol";
import { LibString } from "../lib/solady/src/utils/LibString.sol";
import { JSONParserLib } from "../lib/solady/src/utils/JSONParserLib.sol";
import { IArtifactFactory } from "./interfaces/IArtifactFactory.sol";
import { IGeneralConfig } from "./interfaces/IGeneralConfig.sol";
import { LibSharedAddress } from "./libraries/LibSharedAddress.sol";

contract ArtifactFactory is IArtifactFactory {
  using stdJson for *;
  using StdStyle for *;
  using LibString for *;
  using JSONParserLib for *;

  Vm private constant vm = Vm(LibSharedAddress.VM);
  IGeneralConfig private constant vme = IGeneralConfig(LibSharedAddress.VME);

  function generateArtifact(
    address deployer,
    address contractAddr,
    string memory contractAbsolutePath,
    string memory fileName,
    bytes calldata args,
    uint256 nonce
  ) external {
    console.log(
      string.concat(
        fileName,
        " will be deployed at: ",
        vme.getExplorer(vme.getCurrentNetwork()),
        "address/",
        contractAddr.toHexString()
      ).green(),
      string.concat("(nonce: ", vm.toString(nonce), ")")
    );

    if (!vme.getRuntimeConfig().generateArtifact || vme.isPostChecking()) {
      console.log("Skipping artifact generation for:", vm.getLabel(contractAddr), "\n");
      return;
    }

    string memory dirPath = vme.getDeploymentDirectory(vme.getCurrentNetwork());
    if (!vm.exists(dirPath)) {
      console.log("\n", string.concat(dirPath, " not existed, making one...").yellow());
      vm.createDir(dirPath, true);
      vm.writeFile(string.concat(dirPath, ".chainId"), vm.toString(block.chainid));
    }
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
    json.serialize("blockNumber", vm.getBlockNumber());
    json.serialize("timestamp", vm.getBlockTimestamp());
    json.serialize("contractAbsolutePath", contractAbsolutePath);
    json.serialize("numDeployments", numDeployments);

    string memory artifactPath = contractAbsolutePath;
    if (!artifactPath.endsWith(".json")) {
      string[] memory s = contractAbsolutePath.split(":");
      artifactPath = s.length == 2
        ? string.concat("./out/", s[0], "/", s[1], ".json")
        : string.concat("./out/", contractAbsolutePath, "/", vm.replace(contractAbsolutePath, ".sol", ".json"));
    }

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
