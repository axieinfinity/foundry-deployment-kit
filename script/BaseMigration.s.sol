// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ProxyAdmin } from "../lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {
  ITransparentUpgradeableProxy,
  TransparentUpgradeableProxy
} from "../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { console, LibSharedAddress, StdStyle, IScriptExtended, ScriptExtended } from "./extensions/ScriptExtended.s.sol";
import { IArtifactFactory, ArtifactFactory } from "./ArtifactFactory.sol";
import { IMigrationScript } from "./interfaces/IMigrationScript.sol";
import { LibProxy } from "./libraries/LibProxy.sol";
import { TContract } from "./types/Types.sol";

abstract contract BaseMigration is ScriptExtended {
  using StdStyle for string;
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

  function _storeRawSharedArguments() internal {
    CONFIG.setRawSharedArguments(_sharedArguments());
  }

  function _sharedArguments() internal virtual returns (bytes memory rawSharedArgs);

  function _injectDependencies() internal virtual { }

  function _defaultArguments() internal virtual returns (bytes memory) {
    revert("BaseMigration: _defaultArguments not implemented");
  }

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
    string memory contractName = CONFIG.getContractName(contractType);
    string memory contractAbsolutePath = CONFIG.getContractAbsolutePath(contractType);
    bytes memory args = arguments();
    uint256 nonce;
    (deployed, nonce) = _deployRaw(contractAbsolutePath, args);
    CONFIG.setAddress(network(), contractType, deployed);
    ARTIFACT_FACTORY.generateArtifact(sender(), deployed, contractAbsolutePath, contractName, args, nonce);
  }

  function _deployLogic(TContract contractType) internal virtual returns (address payable logic) {
    string memory contractName = CONFIG.getContractName(contractType);
    string memory contractAbsolutePath = CONFIG.getContractAbsolutePath(contractType);

    uint256 logicNonce;
    (logic, logicNonce) = _deployRaw(contractAbsolutePath, EMPTY_ARGS);
    vm.label(logic, string.concat(contractName, "::Logic[", vm.toString(logic), "]"));

    ARTIFACT_FACTORY.generateArtifact(
      sender(), logic, contractAbsolutePath, string.concat(contractName, "Logic"), EMPTY_ARGS, logicNonce
    );
  }

  function _deployProxy(TContract contractType) internal virtual returns (address payable deployed) {
    string memory contractName = CONFIG.getContractName(contractType);
    bytes memory args = arguments();

    address logic = _deployLogic(contractType);
    string memory proxyAbsolutePath = "TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy";
    uint256 proxyNonce;
    (deployed, proxyNonce) =
      _deployRaw(proxyAbsolutePath, abi.encode(logic, CONFIG.getAddressByString("ProxyAdmin"), args));
    CONFIG.setAddress(network(), contractType, deployed);
    ARTIFACT_FACTORY.generateArtifact(
      sender(), deployed, proxyAbsolutePath, string.concat(contractName, "Proxy"), args, proxyNonce
    );
  }

  function _deployRaw(string memory filename, bytes memory args)
    internal
    virtual
    broadcastAs(sender())
    returns (address payable deployed, uint256 nonce)
  {
    nonce = vm.getNonce(sender());
    deployed = payable(deployCode(filename, args));
  }

  function _upgradeProxy(TContract contractType, bytes memory args) internal virtual returns (address payable proxy) {
    address logic = _deployLogic(contractType);
    proxy = CONFIG.getAddress(network(), contractType);
    _upgradeRaw(proxy.getProxyAdmin(), proxy, logic, args);
  }

  function _upgradeRaw(address proxyAdmin, address payable proxy, address logic, bytes memory args)
    internal
    virtual
    broadcastAs(ProxyAdmin(proxyAdmin).owner())
  {
    ProxyAdmin(proxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(proxy), logic, args);
  }

  function _setDependencyDeployScript(TContract contractType, address deployScript) internal {
    _deployScript[contractType] = IMigrationScript(deployScript);
  }
}
