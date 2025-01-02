// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { stdJson } from "../../dependencies/forge-std-1.9.5/src/StdJson.sol";

import { StdStyle } from "../../dependencies/forge-std-1.9.5/src/StdStyle.sol";
import { Vm } from "../../dependencies/forge-std-1.9.5/src/Vm.sol";
import { console } from "../../dependencies/forge-std-1.9.5/src/console.sol";

import { LibString } from "../../dependencies/solady-0.0.228/src/utils/LibString.sol";
import { IGeneralConfig } from "../interfaces/IGeneralConfig.sol";
import { IRuntimeConfig } from "../interfaces/configs/IRuntimeConfig.sol";
import { LibSharedAddress } from "./LibSharedAddress.sol";

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

  Vm private constant vm = Vm(LibSharedAddress.VM);
  IGeneralConfig private constant vme = IGeneralConfig(LibSharedAddress.VME);

  function generateArtifact(
    ArtifactInfo memory info
  ) internal {
    _logDeployment(info);

    if (!vme.getRuntimeConfig().generateArtifact || vme.isPostChecking()) {
      console.log("Skipping artifact generation for:", vm.getLabel(info.addr), "\n");
      return;
    }

    console.log(string.concat("By: ", vm.getLabel(info.deployer), ", nonce: ", vm.toString(info.nonce), "\n"));

    vm.pauseTracing();

    string memory dirPath = vme.getDeploymentDirectory(vme.getCurrentNetwork());

    _tryCreateDir(dirPath);

    _serializeArtifact(dirPath, info);

    vm.resumeTracing();
  }

  function _serializeArtifact(string memory dirPath, ArtifactInfo memory info) internal {
    string[] memory inputs = new string[](25);
    inputs[0] = "./generate-artifact.sh";
    inputs[1] = "--name";
    inputs[2] = info.contractName;
    inputs[3] = "--args";
    inputs[4] = vm.toString(info.constructorArgs);
    inputs[5] = "--value";
    inputs[6] = vm.toString(info.callValue);
    inputs[7] = "--nonce";
    inputs[8] = vm.toString(info.nonce);
    inputs[9] = "--deployer";
    inputs[10] = vm.toString(info.deployer);
    inputs[11] = "--chainid";
    inputs[12] = vm.toString(block.chainid);
    inputs[13] = "--block-number";
    inputs[14] = vm.toString(vm.getBlockNumber());
    inputs[15] = "--timestamp";
    inputs[16] = vm.toString(vm.getBlockTimestamp());
    inputs[17] = "--absolute-path";
    inputs[18] = info.absolutePath;
    inputs[19] = "--path";
    inputs[20] = dirPath;
    inputs[21] = "--artifact-name";
    inputs[22] = info.artifactName;
    inputs[23] = "--address";
    inputs[24] = vm.toString(info.addr);

    // Write deployment info
    vm.ffi(inputs);
  }

  function _logDeployment(
    ArtifactInfo memory info
  ) internal view {
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

  function _tryCreateDir(
    string memory dirPath
  ) private {
    if (!vm.exists(dirPath)) {
      console.log("\n", string.concat(dirPath, " not existed, making one...").yellow());
      vm.createDir(dirPath, true);
      vm.writeFile(string.concat(dirPath, ".chainId"), vm.toString(block.chainid));
    }
  }

  function _getArtifactPath(
    string memory absolutePath
  ) private pure returns (string memory artifactPath) {
    artifactPath = absolutePath;

    if (!artifactPath.endsWith(".json")) {
      string[] memory s = absolutePath.split(":");
      artifactPath = s.length == 2
        ? string.concat("./out/", s[0], "/", s[1], ".json")
        : string.concat("./out/", absolutePath, "/", vm.replace(absolutePath, ".sol", ".json"));
    }
  }
}
