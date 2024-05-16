// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TransparentProxyV2 } from "../../src/TransparentProxyV2.sol";
import { LegacyTransparentProxy } from "../../src/LegacyTransparentProxy.sol";

import { StdStyle } from "../../lib/forge-std/src/StdStyle.sol";
import { console } from "../../lib/forge-std/src/console.sol";
import { vm, vme } from "../utils/Constants.sol";
import { prankOrBroadcast } from "../utils/Helpers.sol";
import { LibProxy } from "./LibProxy.sol";
import { LibSharedAddress } from "./LibSharedAddress.sol";
import { ArtifactInfo } from "./LibArtifact.sol";

struct DeploymentInfo {
  string absolutePath;
  string contractName;
  string artifactName;
  bytes constructorArgs;
  uint256 callValue;
  address by;
}

using LibDeploy for DeploymentInfo global;

library LibDeploy {
  using StdStyle for string;
  using LibProxy for address;

  function upgradeTransparentProxy(address proxy, address logic, uint256 callValue, bytes memory callData) internal {
    require(
      logic != address(0x0), "LibDeploy: upgradeTransparentProxy(address,address,uint256,bytes): Logic address is 0x0."
    );

    address prevImpl = proxy.getProxyImplementation();

    if (prevImpl.codehash == logic.codehash) {
      string memory answer = vm.prompt(
        string.concat(
          "Proxy: ",
          vm.getLabel(proxy),
          " current implementation ",
          vm.toString(prevImpl),
          " is same as new implementation ",
          vm.toString(logic),
          " Do you want to continue? (y/n)"
        )
      );

      if (keccak256(bytes(answer)) != keccak256("y")) {
        console.log(string.concat("Cancel upgrade for ", vm.getLabel(proxy)).yellow());
        return;
      }

      address proxyAdmin = proxy.getProxyAdmin();

      revert("Unimplemented");
    }
  }

  function deployImplementation(DeploymentInfo memory implInfo) internal returns (address payable impl) {
    require(implInfo.callValue == 0, "LibDeploy: deployImplementation(DeploymentInfo): Value must be 0.");
    implInfo.artifactName = string.concat(implInfo.artifactName, "Logic");
    return deployFromArtifact(implInfo);
  }

  function deployTransparentProxy(
    DeploymentInfo memory implInfo,
    uint256 callValue,
    address proxyAdmin,
    bytes memory callData
  ) internal returns (address payable proxy) {
    address impl = deployImplementation(implInfo);

    DeploymentInfo memory proxyInfo;
    proxyInfo.callValue = callValue;
    proxyInfo.by = implInfo.by;
    proxyInfo.contractName = "TransparentUpgradeableProxyV4_9_5";
    proxyInfo.absolutePath = "TransparentUpgradeableProxyV4_9_5.sol:TransparentUpgradeableProxyV4_9_5";
    proxyInfo.artifactName = string.concat(vm.replace(implInfo.artifactName, "Logic", ""), "Proxy");
    proxyInfo.constructorArgs = abi.encode(impl, proxyAdmin, callData);

    return deployFromArtifact(proxyInfo);
  }

  function deployTransparentProxyV2(
    DeploymentInfo memory implInfo,
    uint256 callValue,
    address proxyAdmin,
    bytes memory callData
  ) internal returns (address payable proxy) {
    address impl = deployImplementation(implInfo);

    DeploymentInfo memory proxyInfo;
    proxyInfo.callValue = callValue;
    proxyInfo.by = implInfo.by;
    proxyInfo.contractName = "TransparentUpgradeableProxyV2";
    proxyInfo.contractName = "TransparentUpgradeableProxyV2.sol:TransparentUpgradeableProxyV2";
    proxyInfo.artifactName = string.concat(vm.replace(implInfo.artifactName, "Logic", ""), "Proxy");
    proxyInfo.constructorArgs = abi.encode(impl, proxyAdmin, callData);

    return deployFromArtifact(proxyInfo);
  }

  function deployFromArtifact(DeploymentInfo memory info) internal returns (address payable deployed) {
    deployed = deployFromBytecode(
      info.absolutePath,
      info.contractName,
      info.artifactName,
      vm.getCode(info.absolutePath),
      info.constructorArgs,
      info.callValue,
      info.by
    );
  }

  function deployFromBytecode(
    string memory absolutePath,
    string memory contractName,
    string memory artifactName,
    bytes memory bytecode,
    bytes memory constructorArgs,
    uint256 callValue,
    address by
  ) internal returns (address payable deployed) {
    uint256 nonce = vm.getNonce(by);

    bytecode = abi.encodePacked(bytecode, constructorArgs);

    prankOrBroadcast(by);

    assembly ("memory-safe") {
      deployed := create(callValue, add(bytecode, 0x20), mload(bytecode))
    }

    require(deployed != address(0x0), "LibDeploy: deployFromBytecode(bytes,bytes,uint256,address): Deployment failed.");

    vme.label(block.chainid, deployed, artifactName);

    ArtifactInfo({
      deployer: by,
      addr: deployed,
      callValue: callValue,
      nonce: nonce,
      absolutePath: absolutePath,
      artifactName: artifactName,
      contractName: contractName,
      constructorArgs: constructorArgs
    }).generateArtifact();
  }

  function _precompileProxyContracts() private pure {
    bytes memory dummy;
    dummy = type(TransparentProxyV2).creationCode;
    dummy = type(LegacyTransparentProxy).creationCode;
  }
}
