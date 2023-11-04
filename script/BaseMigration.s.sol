// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
  ITransparentUpgradeableProxy,
  TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { console2, LibSharedAddress, StdStyle, ScriptExtended } from "./extensions/ScriptExtended.s.sol";
import { ILogger, Logger } from "./Logger.sol";
import { IScript, IDeployScript } from "./interfaces/IDeployScript.sol";
import { LibProxy } from "./libraries/LibProxy.sol";
import { TContract } from "./types/Types.sol";

abstract contract BaseMigration is ScriptExtended {
  using StdStyle for string;
  using LibProxy for address payable;

  ILogger public constant logger = ILogger(LibSharedAddress.logger);

  bytes internal _overriddenArgs;
  mapping(TContract contractType => IDeployScript deployScript) internal _deployScript;

  constructor() {
    _deploySharedAddress(address(logger), type(Logger).creationCode);
    _setMigrationConfig();
    _injectDependencies();
  }

  function loadContractOrDeploy(TContract contractType) public returns (address payable contractAddr) {
    string memory contractName = config.getContractName(contractType);
    try config.getAddressFromCurrentNetwork(contractType) returns (address payable addr) {
      contractAddr = addr;
    } catch {
      console2.log(string.concat("Deployment for ", contractName, " not found, try fresh deploy ...").yellow());
      contractAddr = _deployScript[contractType].run();
    }
  }

  function overrideArgs(bytes memory args) public returns (IDeployScript) {
    _overriddenArgs = args;
    return IDeployScript(address(this));
  }

  function arguments() public returns (bytes memory args) {
    args = _overriddenArgs.length == 0 ? _defaultArguments() : _overriddenArgs;
  }

  function _deployImmutable(TContract contractType) internal returns (address payable deployed) {
    string memory contractName = config.getContractName(contractType);
    string memory contractAbsolutePath = config.getContractAbsolutePath(contractType);
    bytes memory args = arguments();
    uint256 nonce;
    (deployed, nonce) = _deployRaw(contractAbsolutePath, args);
    vm.label(deployed, contractName);

    config.setAddress(network(), contractType, deployed);
    logger.generateArtifact(sender(), deployed, contractAbsolutePath, contractName, args, nonce);
  }

  function _deployLogic(TContract contractType) internal returns (address payable logic) {
    string memory contractName = config.getContractName(contractType);
    string memory contractAbsolutePath = config.getContractAbsolutePath(contractType);

    uint256 logicNonce;
    (logic, logicNonce) = _deployRaw(contractAbsolutePath, EMPTY_ARGS);

    vm.label(logic, string.concat(contractName, "::Logic"));
    logger.generateArtifact(
      sender(), logic, contractAbsolutePath, string.concat(contractName, "Logic"), EMPTY_ARGS, logicNonce
    );
  }

  function _deployProxy(TContract contractType) internal returns (address payable deployed) {
    string memory contractName = config.getContractName(contractType);
    bytes memory args = arguments();

    address logic = _deployLogic(contractType);
    string memory proxyAbsolutePath = "TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy";
    uint256 proxyNonce;
    (deployed, proxyNonce) =
      _deployRaw(proxyAbsolutePath, abi.encode(logic, config.getAddressByString("ProxyAdmin"), args));

    vm.label(deployed, string.concat(contractName, "::Proxy"));
    config.setAddress(network(), contractType, deployed);
    logger.generateArtifact(
      sender(), deployed, proxyAbsolutePath, string.concat(contractName, "Proxy"), args, proxyNonce
    );
  }

  function _deployRaw(string memory filename, bytes memory args)
    internal
    broadcastAs(sender())
    returns (address payable deployed, uint256 nonce)
  {
    nonce = vm.getNonce(sender());
    deployed = payable(deployCode(filename, args));
  }

  function _upgradeProxy(TContract contractType, bytes memory args) internal returns (address payable proxy) {
    address logic = _deployLogic(contractType);
    proxy = config.getAddress(network(), contractType);
    _upgradeRaw(proxy.getProxyAdmin(), proxy, logic, args);
  }

  function _upgradeRaw(address proxyAdmin, address payable proxy, address logic, bytes memory args)
    internal
    broadcastAs(ProxyAdmin(proxyAdmin).owner())
  {
    if (args.length == 0) ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(proxy), logic);
    else ProxyAdmin(proxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(proxy), logic, args);
  }

  function _setMigrationConfig() internal {
    config.setMigrationRawConfig(_buildMigrationRawConfig());
  }

  function _setDependencyDeployScript(TContract contractType, IScript deployScript) internal {
    _deployScript[contractType] = IDeployScript(address(deployScript));
  }

  function _injectDependencies() internal virtual { }

  function _defaultArguments() internal virtual returns (bytes memory args) { }

  function _buildMigrationRawConfig() internal virtual returns (bytes memory);
}
