// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { Vm } from "../../dependencies/forge-std-1.8.2/src/Vm.sol";
import { stdJson } from "../../dependencies/forge-std-1.8.2/src/StdJson.sol";
import { console } from "../../dependencies/forge-std-1.8.2/src/console.sol";
import { StdStyle } from "../../dependencies/forge-std-1.8.2/src/StdStyle.sol";
import { IGeneralConfig } from "../interfaces/IGeneralConfig.sol";
import { LibSharedAddress } from "./LibSharedAddress.sol";
import { LibString } from "../../dependencies/solady-0.0.206/src/utils/LibString.sol";
import { JSONParserLib } from "../../dependencies/solady-0.0.206/src/utils/JSONParserLib.sol";

struct ArtifactInfo {
  address deployer;
  address addr;
  string absolutePath;
  string contractName;
  string artifactName;
  bytes constructorArgs;
  uint256 nonce;
  uint256 callValue;
}

using LibArtifact for ArtifactInfo global;

library LibArtifact {
  using StdStyle for *;
  using stdJson for string;
  using LibString for string;
  using LibString for address;
  using JSONParserLib for string;
  using JSONParserLib for JSONParserLib.Item;

  Vm private constant vm = Vm(LibSharedAddress.VM);
  IGeneralConfig private constant vme = IGeneralConfig(LibSharedAddress.VME);

  function generateArtifact(ArtifactInfo memory info) internal {
    _logDeployment(info);

    if (!vme.getRuntimeConfig().generateArtifact || vme.isPostChecking()) {
      console.log("Skipping artifact generation for:", vm.getLabel(info.addr), "\n");
      return;
    }

    console.log(string.concat("By: ", vm.getLabel(info.deployer), ", nonce: ", vm.toString(info.nonce), "\n"));
    if (!vm.exists("logs")) vm.createDir("logs", true);
    vm.writeLine("logs/deployed-contracts", info.artifactName);

    string memory dirPath = vme.getDeploymentDirectory(vme.getCurrentNetwork());

    _tryCreateDir(dirPath);

    string memory artifact = vm.readFile(_getArtifactPath(info.absolutePath));
    string memory json = _serializeArtifact({ info: info, parsedArtifact: artifact.parse() });

    json.write(string.concat(dirPath, info.artifactName, ".json"));
  }

  function _serializeArtifact(ArtifactInfo memory info, JSONParserLib.Item memory parsedArtifact)
    internal
    returns (string memory json)
  {
    // Write deployment info
    json.serialize("constructorArgs", info.constructorArgs);
    json.serialize("callValue", info.callValue);
    json.serialize("nonce", info.nonce);
    json.serialize("isFoundry", true);
    json.serialize("deployer", info.deployer);
    json.serialize("chainId", block.chainid);
    json.serialize("address", info.addr);
    json.serialize("blockNumber", vm.getBlockNumber());
    json.serialize("timestamp", vm.getBlockTimestamp());
    json.serialize("absolutePath", info.absolutePath);
    json.serialize("contractName", info.contractName);

    // Copy required fields from the parsed artifact in `out` directory
    json.serialize("abi", parsedArtifact.at('"abi"').value());
    json.serialize("ast", parsedArtifact.at('"ast"').value());
    json.serialize("devdoc", parsedArtifact.at('"devdoc"').value());
    json.serialize("userdoc", parsedArtifact.at('"userdoc"').value());
    json.serialize("metadata", parsedArtifact.at('"rawMetadata"').value());
    json.serialize("storageLayout", parsedArtifact.at('"storageLayout"').value());
    json.serialize("bytecode", parsedArtifact.at('"bytecode"').at('"object"').value());
    json = json.serialize("deployedBytecode", parsedArtifact.at('"deployedBytecode"').at('"object"').value());
  }

  function _logDeployment(ArtifactInfo memory info) internal view {
    console.log(
      string.concat(
        vm.getLabel(info.addr),
        " at: ",
        vme.getExplorer(vme.getCurrentNetwork()).cyan(),
        "address/".cyan(),
        info.addr.toHexString().cyan()
      ).green()
    );
  }

  function _tryCreateDir(string memory dirPath) private {
    if (!vm.exists(dirPath)) {
      console.log("\n", string.concat(dirPath, " not existed, making one...").yellow());
      vm.createDir(dirPath, true);
      vm.writeFile(string.concat(dirPath, ".chainId"), vm.toString(block.chainid));
    }
  }

  function _getArtifactPath(string memory absolutePath) private pure returns (string memory artifactPath) {
    artifactPath = absolutePath;

    if (!artifactPath.endsWith(".json")) {
      string[] memory s = absolutePath.split(":");
      artifactPath = s.length == 2
        ? string.concat("./out/", s[0], "/", s[1], ".json")
        : string.concat("./out/", absolutePath, "/", vm.replace(absolutePath, ".sol", ".json"));
    }
  }
}
