// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "../../lib/forge-std/src/Vm.sol";
import { stdJson } from "../../lib/forge-std/src/StdJson.sol";
import { console } from "../../lib/forge-std/src/console.sol";
import { StdStyle } from "../../lib/forge-std/src/StdStyle.sol";
import { IGeneralConfig } from "../interfaces/IGeneralConfig.sol";
import { LibSharedAddress } from "./LibSharedAddress.sol";
import { LibString } from "../../lib/solady/src/utils/LibString.sol";
import { JSONParserLib } from "../../lib/solady/src/utils/JSONParserLib.sol";

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
  using stdJson for string;
  using StdStyle for string;
  using LibString for string;
  using LibString for address;
  using JSONParserLib for string;
  using JSONParserLib for JSONParserLib.Item;

  Vm private constant vm = Vm(LibSharedAddress.VM);
  IGeneralConfig private constant vme = IGeneralConfig(LibSharedAddress.VME);

  function generateArtifact(ArtifactInfo memory info) internal {
    _logDeployment(info.addr, info.nonce);

    if (!vme.getRuntimeConfig().generateArtifact || vme.isPostChecking()) {
      console.log("Skipping artifact generation for:", vm.getLabel(info.addr), "\n");
      return;
    }

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

  function _logDeployment(address addr, uint256 nonce) internal view {
    console.log(
      string.concat(
        "Deployed ",
        vm.getLabel(addr),
        " at: ",
        vme.getExplorer(vme.getCurrentNetwork()),
        "address/",
        addr.toHexString()
      ).green(),
      string.concat("(nonce: ", vm.toString(nonce), ")")
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
