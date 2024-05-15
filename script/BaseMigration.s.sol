// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ProxyAdmin } from "../lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {
  ITransparentUpgradeableProxy, TransparentUpgradeableProxyV4_9_5
} from "../src/TransparentUpgradeableProxyV4_9_5.sol";
import { LibString } from "../lib/solady/src/utils/LibString.sol";
import { console } from "../lib/forge-std/src/console.sol";
import { StdStyle } from "../lib/forge-std/src/StdStyle.sol";
import { IScriptExtended, ScriptExtended } from "./extensions/ScriptExtended.s.sol";
import { OnchainExecutor } from "./OnchainExecutor.s.sol"; // cheat to load artifact to parent `out` directory
import { IMigrationScript } from "./interfaces/IMigrationScript.sol";
import { LibProxy } from "./libraries/LibProxy.sol";
import { LibDeploy, DeploymentInfo } from "./libraries/LibDeploy.sol";
import { DefaultContract } from "./utils/DefaultContract.sol";
import { TContract } from "./types/Types.sol";
import { loadContract, prankOrBroadcast } from "./utils/Utils.sol";
import { vme, EMPTY_ARGS } from "./utils/Constants.sol";

import { LibSharedAddress } from "./libraries/LibSharedAddress.sol";
import { LibErrorHandler } from "../lib/contract-libs/src/LibErrorHandler.sol";

abstract contract BaseMigration is ScriptExtended {
  using StdStyle for *;
  using LibString for bytes32;
  using LibErrorHandler for bool;
  using LibProxy for address payable;

  bytes internal _overriddenArgs;
  mapping(TContract contractType => IMigrationScript deployScript) internal _deployScript;

  function setUp() public virtual override {
    super.setUp();

    // store raw shared arguments
    if (vme.areSharedArgumentsStored()) return;
    vme.setRawSharedArguments(_sharedArguments());

    _injectDependencies();
  }

  function _sharedArguments() internal virtual returns (bytes memory rawSharedArgs);

  function _injectDependencies() internal virtual { }

  function _defaultArguments() internal virtual returns (bytes memory) { }

  function loadContractOrDeploy(TContract contractType) public virtual returns (address payable contractAddr) {
    string memory contractName = vme.getContractName(contractType);

    contractAddr = loadContract({ contractType: contractType, shouldRevert: false });

    if (contractAddr == address(0x0)) {
      console.log(string.concat("Deployment for ", contractName, " not found, try fresh deploy ...").yellow());
      contractAddr = _deployScript[contractType].run();
    }
  }

  function overrideArgs(bytes memory args) public virtual returns (IMigrationScript) {
    _overriddenArgs = args;
    return IMigrationScript(address(this));
  }

  function arguments() public virtual returns (bytes memory args) {
    args = _overriddenArgs.length == 0 ? _defaultArguments() : _overriddenArgs;
  }

  function _getProxyAdmin() internal virtual returns (address payable proxyAdmin) {
    proxyAdmin = loadContract(DefaultContract.ProxyAdmin.key());
  }

  function _deployImmutable(TContract contractType) internal virtual returns (address payable deployed) {
    deployed = _deployImmutable(contractType, arguments());
  }

  function _deployImmutable(TContract contractType, bytes memory args)
    internal
    virtual
    logFn(string.concat("_deployImmutable ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable deployed)
  {
    string memory contractName = vme.getContractName(contractType);

    deployed = DeploymentInfo({
      callValue: 0,
      by: sender(),
      contractName: contractName,
      absolutePath: vme.getContractAbsolutePath(contractType),
      artifactName: contractName,
      constructorArgs: args
    }).deployFromArtifact();

    vme.setAddress(network(), contractType, deployed);
  }

  function _deployLogic(TContract contractType) internal virtual returns (address payable logic) {
    logic = _deployLogic(contractType, EMPTY_ARGS);
  }

  function _deployLogic(TContract contractType, bytes memory args)
    internal
    virtual
    logFn(string.concat("_deployLogic ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable logic)
  {
    string memory contractName = vme.getContractName(contractType);

    logic = DeploymentInfo({
      callValue: 0,
      by: sender(),
      contractName: contractName,
      absolutePath: vme.getContractAbsolutePath(contractType),
      artifactName: contractName,
      constructorArgs: args
    }).deployImplementation();

    vme.label(block.chainid, logic, string.concat(contractName, "::Logic"));
  }

  function _deployProxy(TContract contractType) internal virtual returns (address payable deployed) {
    deployed = _deployProxy(contractType, arguments());
  }

  function _deployProxy(TContract contractType, bytes memory args) internal virtual returns (address payable deployed) {
    deployed = _deployProxy(contractType, args, EMPTY_ARGS);
  }

  function _deployProxy(TContract contractType, bytes memory args, bytes memory argsLogicConstructor)
    internal
    virtual
    logFn(string.concat("_deployProxy ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable deployed)
  {
    string memory contractName = vme.getContractName(contractType);

    address proxyAdmin = _getProxyAdmin();
    assertTrue(proxyAdmin != address(0x0), "BaseMigration: Null ProxyAdmin");

    deployed = LibDeploy.deployTransparentProxy({
      implInfo: DeploymentInfo({
        callValue: 0,
        by: sender(),
        contractName: contractName,
        absolutePath: vme.getContractAbsolutePath(contractType),
        artifactName: contractName,
        constructorArgs: argsLogicConstructor
      }),
      callValue: 0,
      proxyAdmin: _getProxyAdmin(),
      callData: args
    });

    // validate proxy admin
    address actualProxyAdmin = deployed.getProxyAdmin();
    assertEq(
      actualProxyAdmin,
      proxyAdmin,
      string.concat(
        "BaseMigration: Invalid proxy admin\n",
        "Actual: ",
        vm.toString(actualProxyAdmin),
        "\nExpected: ",
        vm.toString(proxyAdmin)
      )
    );

    vme.setAddress(network(), contractType, deployed);
  }

  function _upgradeProxy(TContract contractType) internal virtual returns (address payable proxy) {
    proxy = _upgradeProxy(contractType, arguments());
  }

  function _upgradeProxy(TContract contractType, bytes memory args) internal virtual returns (address payable proxy) {
    proxy = _upgradeProxy(contractType, args, EMPTY_ARGS);
  }

  function _upgradeProxy(TContract contractType, bytes memory args, bytes memory argsLogicConstructor)
    internal
    virtual
    logFn(string.concat("_upgradeProxy ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable proxy)
  {
    address logic = _deployLogic(contractType, argsLogicConstructor);
    proxy = vme.getAddress(network(), contractType);
    _upgradeRaw(proxy.getProxyAdmin(), proxy, logic, args);
  }

  function _upgradeRaw(address proxyAdmin, address payable proxy, address logic, bytes memory args) internal virtual {
    if (logic.codehash == payable(proxy).getProxyImplementation({ nullCheck: true }).codehash) {
      console.log("BaseMigration: Logic is already upgraded!".yellow());
      return;
    }

    ITransparentUpgradeableProxy iProxy = ITransparentUpgradeableProxy(proxy);
    ProxyAdmin wProxyAdmin = ProxyAdmin(proxyAdmin);

    // if proxyAdmin is External Owned Wallet
    if (proxyAdmin.code.length == 0) {
      prankOrBroadcast(proxyAdmin);
      if (args.length == 0) iProxy.upgradeTo(logic);
      else iProxy.upgradeToAndCall(logic, args);
    } else {
      try wProxyAdmin.owner() returns (address owner) {
        if (args.length == 0) {
          // try `upgrade(address,address)` function
          vm.prank(owner);
          (bool success,) = proxyAdmin.call(abi.encodeCall(ProxyAdmin.upgrade, (iProxy, logic)));
          if (success) {
            if (owner.code.length != 0) {
              _cheatUpgrade(owner, wProxyAdmin, iProxy, logic);
            } else {
              prankOrBroadcast(owner);
              wProxyAdmin.upgrade(iProxy, logic);
            }
          } else {
            console.log(
              "`ProxyAdmin:upgrade` failed!. Retrying with `ProxyAdmin:upgradeAndCall` with empty args...".yellow()
            );
            if (owner.code.length != 0) {
              _cheatUpgradeAndCall(owner, wProxyAdmin, iProxy, logic, args);
            } else {
              prankOrBroadcast(owner);
              wProxyAdmin.upgradeAndCall(iProxy, logic, args);
            }
          }
        } else {
          if (owner.code.length != 0) {
            _cheatUpgradeAndCall(owner, wProxyAdmin, iProxy, logic, args);
          } else {
            prankOrBroadcast(owner);
            wProxyAdmin.upgradeAndCall(iProxy, logic, args);
          }
        }
      } catch {
        revert("BaseMigration: Unknown ProxyAdmin contract!");
      }
    }
  }

  function _cheatUpgrade(address owner, ProxyAdmin wProxyAdmin, ITransparentUpgradeableProxy iProxy, address logic)
    internal
    virtual
  {
    bytes memory callData = abi.encodeCall(ProxyAdmin.upgrade, (iProxy, logic));
    string[] memory commandInputs = new string[](3);
    commandInputs[0] = "cast";
    commandInputs[1] = "4byte-decode";
    commandInputs[2] = vm.toString(callData);
    string memory decodedCallData = string(vm.ffi(commandInputs));

    console.log(
      "------------------------------------------------------------------------------- Multi-Sig Proposal -------------------------------------------------------------------------------"
    );
    console.log("To:".cyan(), vm.getLabel(address(wProxyAdmin)));
    console.log(
      "Raw Calldata Data (Please double check using `cast 4byte-decode {raw_bytes}`):\n".cyan(),
      string.concat(" - ", vm.toString(callData))
    );
    console.log(
      "Method:\n".cyan(),
      string.concat(" - upgrade(address,address)\n  - ", vm.getLabel(address(iProxy)), "\n  - ", vm.getLabel(logic))
    );
    console.log("Cast Decoded Call Data:".cyan(), decodedCallData);
    console.log(
      "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
    );

    // cheat prank to update `implementation slot` for next call
    vm.prank(owner);
    wProxyAdmin.upgrade(iProxy, logic);
  }

  function _cheatUpgradeAndCall(
    address owner,
    ProxyAdmin wProxyAdmin,
    ITransparentUpgradeableProxy iProxy,
    address logic,
    bytes memory args
  ) internal virtual {
    bytes memory callData = abi.encodeCall(ProxyAdmin.upgradeAndCall, (iProxy, logic, args));
    string[] memory commandInputs = new string[](3);
    commandInputs[0] = "cast";
    commandInputs[1] = "4byte-decode";
    commandInputs[2] = vm.toString(callData);
    string memory decodedCallData = string(vm.ffi(commandInputs));
    commandInputs[2] = vm.toString(args);
    string memory decodedInnerCall = string(vm.ffi(commandInputs));

    console.log(
      "------------------------------------------------------------------------------- Multi-Sig Proposal -------------------------------------------------------------------------------"
    );
    console.log("To:".cyan(), vm.getLabel(address(wProxyAdmin)));
    console.log(
      "Raw Call Data (Please double check using `cast 4byte-decode {raw_bytes}`):\n".cyan(),
      " - ",
      vm.toString(callData)
    );
    console.log(
      "Method:\n".cyan(),
      " - upgradeAndCall(address,address,bytes)\n",
      string.concat(" - ", vm.getLabel(address(iProxy)), "\n  - ", vm.getLabel(logic), "\n  - ", vm.toString(args))
    );
    console.log("Cast Decoded Call Data:".cyan(), decodedCallData);
    console.log("Cast Decoded Inner Method:".cyan(), decodedInnerCall);
    console.log(
      "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------\n\n"
    );

    // cheat prank to update `implementation slot` for next call
    vm.prank(owner);
    wProxyAdmin.upgradeAndCall(iProxy, logic, args);
  }

  function _setDependencyDeployScript(TContract contractType, IScriptExtended deployScript) internal virtual {
    _setDependencyDeployScript(contractType, address(deployScript));
  }

  function _setDependencyDeployScript(TContract contractType, address deployScript) internal virtual {
    _deployScript[contractType] = IMigrationScript(deployScript);

    vm.makePersistent(deployScript);
    vm.allowCheatcodes(deployScript);
  }
}
