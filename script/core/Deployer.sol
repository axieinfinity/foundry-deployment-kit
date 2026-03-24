// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { CommonBase } from "forge-std/Base.sol";
import { console } from "forge-std/console.sol";

import { LibProxy } from "../libraries/LibProxy.sol";
import { IEIP173 } from "../interfaces/IEIP173.sol";

/**
 * @dev Lightweight stateless deploy/upgrade helpers.
 *
 * Unlike BaseMigration, this contract has NO dependency on:
 * - VME / BaseGeneralConfig / config mixins
 * - Proxy contract source files (deploys via vm.getCode artifact lookup)
 * - ScriptExtended / StdAssertions
 * - LibArtifact (no artifact file generation)
 *
 * Consumer tests can inherit this for simple deploy/upgrade flows.
 */
abstract contract Deployer is CommonBase {
  using LibProxy for address;
  using LibProxy for address payable;

  function _deployRaw(
    bytes memory creationCode
  ) internal returns (address deployed) {
    assembly ("memory-safe") {
      deployed := create(0, add(creationCode, 0x20), mload(creationCode))
    }
    require(deployed != address(0), "Deployer: Deployment failed");
    require(deployed.code.length > 0, "Deployer: Empty code after deploy");
  }

  function _deployRaw(bytes memory creationCode, bytes memory constructorArgs) internal returns (address deployed) {
    return _deployRaw(abi.encodePacked(creationCode, constructorArgs));
  }

  function _deployFromArtifact(
    string memory artifactPath
  ) internal returns (address deployed) {
    return _deployRaw(vm.getCode(artifactPath));
  }

  function _deployFromArtifact(
    string memory artifactPath,
    bytes memory constructorArgs
  ) internal returns (address deployed) {
    return _deployRaw(vm.getCode(artifactPath), constructorArgs);
  }

  /**
   * @dev Deploy an implementation contract from an artifact path.
   */
  function _deployLogic(
    string memory artifactPath
  ) internal returns (address logic) {
    logic = _deployFromArtifact(artifactPath);
  }

  function _deployLogic(string memory artifactPath, bytes memory constructorArgs) internal returns (address logic) {
    logic = _deployFromArtifact(artifactPath, constructorArgs);
  }

  /**
   * @dev Deploy a TransparentUpgradeableProxy (OZ v4 style) from artifact.
   * Does NOT import the proxy .sol file; uses vm.getCode to load compiled artifact.
   */
  function _deployTransparentProxy(
    string memory implArtifactPath,
    address proxyAdmin,
    bytes memory initData
  ) internal returns (address proxy) {
    return _deployTransparentProxy(implArtifactPath, "", proxyAdmin, initData);
  }

  function _deployTransparentProxy(
    string memory implArtifactPath,
    bytes memory implConstructorArgs,
    address proxyAdmin,
    bytes memory initData
  ) internal returns (address proxy) {
    require(proxyAdmin != address(0), "Deployer: Null proxy admin");

    address impl = bytes(implConstructorArgs).length > 0
      ? _deployFromArtifact(implArtifactPath, implConstructorArgs)
      : _deployFromArtifact(implArtifactPath);

    bytes memory proxyCreationCode = vm.getCode("TransparentProxyOZv4_9_5.sol:TransparentProxyOZv4_9_5");
    proxy = _deployRaw(proxyCreationCode, abi.encode(impl, proxyAdmin, initData));

    address actualAdmin = proxy.getProxyAdmin();
    require(
      actualAdmin == proxyAdmin,
      string.concat(
        "Deployer: Proxy admin mismatch. Expected: ",
        vm.toString(proxyAdmin),
        " Got: ",
        vm.toString(actualAdmin)
      )
    );
  }

  /**
   * @dev Upgrade a transparent proxy to a new implementation.
   */
  function _upgradeProxy(address proxy, address newLogic, bytes memory callData) internal {
    require(newLogic != address(0), "Deployer: Null logic");

    (address auth, address interactTo) = _findHierarchyAdmin(proxy);
    bool isViaAuxiliary = interactTo != proxy;

    bytes memory upgradeCallData;
    if (isViaAuxiliary) {
      upgradeCallData = callData.length == 0
        ? abi.encodeWithSignature("upgrade(address,address)", proxy, newLogic)
        : abi.encodeWithSignature("upgradeAndCall(address,address,bytes)", proxy, newLogic, callData);
    } else {
      upgradeCallData = callData.length == 0
        ? abi.encodeWithSignature("upgradeTo(address)", newLogic)
        : abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newLogic, callData);
    }

    vm.prank(auth);
    (bool success, bytes memory ret) = interactTo.call(upgradeCallData);
    require(success, string.concat("Deployer: Upgrade failed: ", vm.toString(ret)));
  }

  function _findHierarchyAdmin(
    address proxy
  ) internal view returns (address auth, address interactTo) {
    interactTo = proxy;
    auth = proxy.getProxyAdmin();

    while (true) {
      if (auth.code.length == 0) return (auth, interactTo);

      try IEIP173(auth).owner() returns (address owner) {
        if (owner == address(0)) return (auth, interactTo);
        interactTo = auth;
        auth = owner;
      } catch {
        return (auth, interactTo);
      }
    }
  }
}
