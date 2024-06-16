// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { TransparentProxyV2 } from "../../src/TransparentProxyV2.sol";
import { TransparentProxyOZv4_9_5 } from "../../src/TransparentProxyOZv4_9_5.sol";
import { ITransparentUpgradeableProxy } from
  "../../dependencies/@openzeppelin-contracts-4.9.3/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "../../dependencies/@openzeppelin-contracts-4.9.3/proxy/transparent/ProxyAdmin.sol";
import { StdStyle } from "../../dependencies/forge-std-1.8.2/src/StdStyle.sol";
import { console } from "../../dependencies/forge-std-1.8.2/src/console.sol";
import { vm, vme } from "../utils/Constants.sol";
import { sendRawTransaction, cheatBroadcast, decodeData } from "../utils/Helpers.sol";
import { LibProxy } from "./LibProxy.sol";
import { LibSharedAddress } from "./LibSharedAddress.sol";
import { ArtifactInfo } from "./LibArtifact.sol";

enum ProxyInterface {
  Transparent,
  Beacon,
  UUPS
}

struct DeployInfo {
  string absolutePath;
  string contractName;
  string artifactName;
  bytes constructorArgs;
  uint256 callValue;
  address by;
}

struct UpgradeInfo {
  address proxy;
  address logic;
  uint256 callValue;
  bytes callData;
  ProxyInterface proxyInterface;
  function(address,address,uint256,bytes memory,ProxyInterface) external upgradeCallback;
  bool shouldUseCallback;
  bool shouldPrompt;
}

using LibDeploy for DeployInfo global;
using LibDeploy for UpgradeInfo global;

library LibDeploy {
  using StdStyle for string;
  using LibProxy for address;
  using LibProxy for address payable;

  modifier prankOrBroadcast(address by) {
    if (vme.isPostChecking()) {
      vm.startPrank(by);
      _;
      vm.stopPrank();
    } else {
      vm.startBroadcast(by);
      _;
      vm.stopBroadcast();
    }
  }

  modifier validateUpgrade(address proxy, address newImpl, bool shouldPrompt) {
    require(newImpl != address(0x0), "LibDeploy: Logic address is 0x0.");

    address prevProxyAdmin = proxy.getProxyAdmin();
    address prevImpl = proxy.getProxyImplementation();

    if (prevImpl.codehash == newImpl.codehash && shouldPrompt && !vme.isPostChecking()) {
      try vm.prompt(
        string.concat(
          "Proxy: ",
          vm.getLabel(proxy),
          "\nCurrent implementation ",
          vm.toString(prevImpl),
          " is same as new implementation ",
          vm.toString(newImpl),
          "\nDo you want to continue? (y/n)"
        )
      ) returns (string memory answer) {
        if (keccak256(bytes(answer)) != keccak256("y")) {
          console.log(string.concat("Cancel upgrade for ", vm.getLabel(proxy)).yellow());
          return;
        }
      } catch {
        console.log(
          string.concat(
            "WARNING: Re-upgrading contract with similar logic as current implementation ", vm.getLabel(proxy)
          ).yellow()
        );
      }
    }

    _;

    address currProxyAdmin = proxy.getProxyAdmin();
    address currImpl = proxy.getProxyImplementation();

    require(currImpl != address(0x0), "LibDeploy: Null Implementation");
    require(currProxyAdmin != address(0x0), "LibDeploy: Null ProxyAdmin");
    require(currProxyAdmin == prevProxyAdmin, "LibDeploy: ProxyAdmin changed");
  }

  function upgrade(UpgradeInfo memory info) internal {
    if (info.proxyInterface == ProxyInterface.Transparent) {
      upgradeTransparentProxy(
        info.proxy,
        info.logic,
        info.callValue,
        info.callData,
        info.shouldPrompt,
        info.upgradeCallback,
        info.shouldUseCallback
      );
    } else {
      revert("LibDeploy: Unsupported proxy interface for now.");
    }
  }

  function upgradeTransparentProxy(
    address proxy,
    address logic,
    uint256 callValue,
    bytes memory callData,
    bool shouldPrompt,
    function(address,address,uint256,bytes memory,ProxyInterface) external upgradeCallback,
    bool shouldUseCallback
  ) internal validateUpgrade(proxy, logic, shouldPrompt) {
    if (shouldUseCallback) {
      upgradeCallback(proxy, logic, callValue, callData, ProxyInterface.Transparent);
    } else {
      _tryUpgradeTransparentProxy(proxy, logic, callValue, callData);
    }
  }

  function _tryUpgradeTransparentProxy(address proxy, address logic, uint256 callValue, bytes memory callData) private {
    (address auth, address interactTo) = findHierarchyAdminOfProxy(proxy);
    bool isViaAuxiliary = interactTo != proxy;

    if (isViaAuxiliary) {
      callData = callData.length == 0
        ? abi.encodeCall(ProxyAdmin.upgrade, (ITransparentUpgradeableProxy(proxy), logic))
        : abi.encodeCall(ProxyAdmin.upgradeAndCall, (ITransparentUpgradeableProxy(proxy), logic, callData));
    } else {
      callData = callData.length == 0
        ? abi.encodeCall(ITransparentUpgradeableProxy.upgradeTo, (logic))
        : abi.encodeCall(ITransparentUpgradeableProxy.upgradeToAndCall, (logic, callData));
    }

    bool shouldCheatCall = auth.code.length != 0;
    if (shouldCheatCall) {
      console.log(
        string.concat(
          "LibDeploy: upgradeTransparentProxy(address,address,uint256,bytes): ",
          "Cannot upgrade proxy ",
          vm.getLabel(proxy),
          " because it is managed by an admin contract."
        )
      );

      cheatBroadcast({ from: auth, to: interactTo, callValue: callValue, callData: callData });
    } else {
      sendRawTransaction({ from: auth, to: interactTo, callValue: callValue, callData: callData, gas: 0 });
    }
  }

  function findHierarchyAdminOfProxy(address proxy) internal view returns (address auth, address interactTo) {
    interactTo = proxy;
    auth = proxy.getProxyAdmin();

    while (true) {
      if (auth.code.length == 0) return (auth, interactTo);

      try ProxyAdmin(auth).owner() returns (address owner) {
        if (owner == address(0x0)) return (auth, interactTo);

        interactTo = auth;
        auth = owner;
      } catch {
        return (auth, interactTo);
      }
    }
  }

  function deployImplementation(DeployInfo memory implInfo) internal returns (address payable impl) {
    require(implInfo.callValue == 0, "LibDeploy: deployImplementation(DeployInfo): Value must be 0.");
    implInfo.artifactName = string.concat(implInfo.artifactName, "Logic");
    return deployFromArtifact(implInfo);
  }

  function deployTransparentProxy(
    DeployInfo memory implInfo,
    uint256 callValue,
    address proxyAdmin,
    bytes memory callData
  ) internal returns (address payable proxy) {
    require(proxyAdmin != address(0x0), "BaseMigration: Null ProxyAdmin");

    address impl = deployImplementation(implInfo);

    DeployInfo memory proxyInfo;
    proxyInfo.callValue = callValue;
    proxyInfo.by = implInfo.by;
    proxyInfo.contractName = type(TransparentProxyOZv4_9_5).name;
    proxyInfo.absolutePath = string.concat(proxyInfo.contractName, ".sol:", proxyInfo.contractName);
    proxyInfo.artifactName = string.concat(vm.replace(implInfo.artifactName, "Logic", ""), "Proxy");
    proxyInfo.constructorArgs = abi.encode(impl, proxyAdmin, callData);

    proxy = deployFromArtifact(proxyInfo);

    // validate proxy admin
    address actualProxyAdmin = proxy.getProxyAdmin();
    require(
      actualProxyAdmin == proxyAdmin,
      string.concat(
        "LibDeploy: Invalid proxy admin\n",
        "Actual: ",
        vm.toString(actualProxyAdmin),
        "\nExpected: ",
        vm.toString(proxyAdmin)
      )
    );
  }

  function deployTransparentProxyV2(
    DeployInfo memory implInfo,
    uint256 callValue,
    address proxyAdmin,
    bytes memory callData
  ) internal returns (address payable proxy) {
    address impl = deployImplementation(implInfo);

    DeployInfo memory proxyInfo;
    proxyInfo.callValue = callValue;
    proxyInfo.by = implInfo.by;
    proxyInfo.contractName = type(TransparentProxyV2).name;
    proxyInfo.absolutePath = string.concat(proxyInfo.contractName, ".sol:", proxyInfo.contractName);
    proxyInfo.artifactName = string.concat(vm.replace(implInfo.artifactName, "Logic", ""), "Proxy");
    proxyInfo.constructorArgs = abi.encode(impl, proxyAdmin, callData);

    return deployFromArtifact(proxyInfo);
  }

  function deployFromArtifact(DeployInfo memory info) internal returns (address payable deployed) {
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

    deployed = _deployRaw(callValue, bytecode, by);

    require(deployed != address(0x0), "LibDeploy: deployFromBytecode(bytes,bytes,uint256,address): Deployment failed.");
    require(deployed.code.length > 0, "LibDeploy: deployFromBytecode(bytes,bytes,uint256,address): Empty code.");

    vme.label(vme.getCurrentNetwork(), deployed, artifactName);

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

  function _deployRaw(uint256 callValue, bytes memory bytecode, address by)
    private
    prankOrBroadcast(by)
    returns (address payable deployed)
  {
    assembly ("memory-safe") {
      deployed := create(callValue, add(bytecode, 0x20), mload(bytecode))
    }
  }

  function _precompileProxyContracts() private pure {
    bytes memory dummy;
    dummy = type(TransparentProxyV2).creationCode;
    dummy = type(TransparentProxyOZv4_9_5).creationCode;
  }
}
