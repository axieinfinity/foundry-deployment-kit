// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ProxyAdmin } from "../lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {
  ITransparentUpgradeableProxy,
  TransparentUpgradeableProxy
} from "../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { LibString } from "../lib/solady/src/utils/LibString.sol";
import { console, LibSharedAddress, StdStyle, IScriptExtended, ScriptExtended } from "./extensions/ScriptExtended.s.sol";
import { IArtifactFactory, ArtifactFactory } from "./ArtifactFactory.sol";
import { IMigrationScript } from "./interfaces/IMigrationScript.sol";
import { LibProxy } from "./libraries/LibProxy.sol";
import { DefaultContract } from "./utils/DefaultContract.sol";
import { TContract } from "./types/Types.sol";

abstract contract BaseMigration is ScriptExtended {
  using StdStyle for string;
  using LibString for bytes32;
  using LibProxy for address payable;

  IArtifactFactory public constant ARTIFACT_FACTORY = IArtifactFactory(LibSharedAddress.ARTIFACT_FACTORY);

  bytes internal _overriddenArgs;
  mapping(TContract contractType => IMigrationScript deployScript) internal _deployScript;

  function setUp() public virtual override {
    super.setUp();
    vm.label(address(ARTIFACT_FACTORY), "ArtifactFactory");
    deploySharedAddress(address(ARTIFACT_FACTORY), type(ArtifactFactory).creationCode);
    _injectDependencies();
    _storeRawSharedArguments();
  }

  function _storeRawSharedArguments() internal virtual {
    CONFIG.setRawSharedArguments(_sharedArguments());
  }

  function _sharedArguments() internal virtual returns (bytes memory rawSharedArgs);

  function _injectDependencies() internal virtual { }

  function _defaultArguments() internal virtual returns (bytes memory) { }

  function loadContractOrDeploy(TContract contractType) public virtual returns (address payable contractAddr) {
    string memory contractName = CONFIG.getContractName(contractType);
    try CONFIG.getAddressFromCurrentNetwork(contractType) returns (address payable addr) {
      contractAddr = addr;
    } catch {
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

  function _deployImmutable(TContract contractType) internal virtual returns (address payable deployed) {
    deployed = _deployImmutable(contractType, arguments());
  }

  function _deployImmutable(TContract contractType, bytes memory args)
    internal
    virtual
    logFn(string.concat("_deployImmutable ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable deployed)
  {
    string memory contractName = CONFIG.getContractName(contractType);
    string memory contractAbsolutePath = CONFIG.getContractAbsolutePath(contractType);
    uint256 nonce;
    (deployed, nonce) = _deployRaw(contractAbsolutePath, args);
    CONFIG.setAddress(network(), contractType, deployed);
    ARTIFACT_FACTORY.generateArtifact(sender(), deployed, contractAbsolutePath, contractName, args, nonce);
  }

  function _deployLogic(TContract contractType)
    internal
    virtual
    logFn(string.concat("_deployLogic ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable logic)
  {
    string memory contractName = CONFIG.getContractName(contractType);
    string memory contractAbsolutePath = CONFIG.getContractAbsolutePath(contractType);

    uint256 logicNonce;
    (logic, logicNonce) = _deployRaw(contractAbsolutePath, EMPTY_ARGS);
    CONFIG.label(block.chainid, logic, string.concat(contractName, "::Logic"));
    ARTIFACT_FACTORY.generateArtifact(
      sender(), logic, contractAbsolutePath, string.concat(contractName, "Logic"), EMPTY_ARGS, logicNonce
    );
  }

  function _deployProxy(TContract contractType) internal virtual returns (address payable deployed) {
    deployed = _deployProxy(contractType, arguments());
  }

  function _deployProxy(TContract contractType, bytes memory args)
    internal
    virtual
    logFn(string.concat("_deployProxy ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable deployed)
  {
    string memory contractName = CONFIG.getContractName(contractType);

    address logic = _deployLogic(contractType);
    string memory proxyAbsolutePath = "TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy";
    uint256 proxyNonce;
    address proxyAdmin = CONFIG.getAddressFromCurrentNetwork(DefaultContract.ProxyAdmin.key());
    assertTrue(proxyAdmin != address(0x0), "BaseMigration: Null ProxyAdmin");

    (deployed, proxyNonce) = _deployRaw(proxyAbsolutePath, abi.encode(logic, proxyAdmin, args));

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

    CONFIG.setAddress(network(), contractType, deployed);
    ARTIFACT_FACTORY.generateArtifact(
      sender(), deployed, proxyAbsolutePath, string.concat(contractName, "Proxy"), args, proxyNonce
    );
  }

  function _deployRaw(string memory filename, bytes memory args)
    internal
    virtual
    returns (address payable deployed, uint256 nonce)
  {
    nonce = vm.getNonce(sender());
    vm.broadcast(sender());
    deployed = payable(deployCode(filename, args));
  }

  function _mockUpgradeProxy(TContract contractType)
    internal
    virtual
    logFn(string.concat("_mockUpgradeProxy ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable proxy)
  {
    proxy = _mockUpgradeProxy(contractType, arguments());
  }

  function _mockUpgradeProxy(TContract contractType, bytes memory args)
    internal
    virtual
    logFn(string.concat("_mockUpgradeProxy ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable proxy)
  {
    address logic = _deployLogic(contractType);
    proxy = CONFIG.getAddress(network(), contractType);
    _mockUpgradeRaw(proxy.getProxyAdmin(), proxy, logic, args);
  }

  function _upgradeProxy(TContract contractType)
    internal
    virtual
    returns (address payable proxy)
  {
    proxy = _upgradeProxy(contractType, arguments());
  }

  function _upgradeProxy(TContract contractType, bytes memory args)
    internal
    virtual
    logFn(string.concat("_upgradeProxy ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable proxy)
  {
    address logic = _deployLogic(contractType);
    proxy = CONFIG.getAddress(network(), contractType);
    _upgradeRaw(proxy.getProxyAdmin(), proxy, logic, args);
  }

  function _mockUpgradeRaw(address proxyAdmin, address payable proxy, address logic, bytes memory args)
    internal
    virtual
  {
    if (proxyAdmin.code.length == 0) {
      vm.prank(proxyAdmin);
      if (args.length == 0) ITransparentUpgradeableProxy(proxy).upgradeTo(logic);
      else ITransparentUpgradeableProxy(proxy).upgradeToAndCall(logic, args);
    } else {
      try ProxyAdmin(proxyAdmin).owner() returns (address owner) {
        vm.prank(owner);
        if (args.length == 0) {
          ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(proxy), logic);
        } else {
          ProxyAdmin(proxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(proxy), logic, args);
        }
      } catch {
        vm.prank(proxyAdmin);
        if (args.length == 0) ITransparentUpgradeableProxy(proxy).upgradeTo(logic);
        else ITransparentUpgradeableProxy(proxy).upgradeToAndCall(logic, args);
      }
    }
  }

  function _upgradeRaw(address proxyAdmin, address payable proxy, address logic, bytes memory args) internal virtual {
    if (proxyAdmin.code.length == 0) {
      vm.broadcast(proxyAdmin);
      if (args.length == 0) ITransparentUpgradeableProxy(proxy).upgradeTo(logic);
      else ITransparentUpgradeableProxy(proxy).upgradeToAndCall(logic, args);
    } else {
      try ProxyAdmin(proxyAdmin).owner() returns (address owner) {
        vm.broadcast(owner);
        if (args.length == 0) {
          ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(proxy), logic);
        } else {
          ProxyAdmin(proxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(proxy), logic, args);
        }
      } catch {
        revert("BaseMigration: Unhandled case for upgrading proxy!");
      }
    }
  }

  function _setDependencyDeployScript(TContract contractType, IScriptExtended deployScript) internal virtual {
    _deployScript[contractType] = IMigrationScript(address(deployScript));
  }

  function _setDependencyDeployScript(TContract contractType, address deployScript) internal virtual {
    _deployScript[contractType] = IMigrationScript(deployScript);
  }
}
