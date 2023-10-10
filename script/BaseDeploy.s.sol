// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ProxyAdmin, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {StdStyle} from "forge-std/StdStyle.sol";
import {BaseScript} from "./BaseScript.s.sol";
import {LogGenerator} from "./LogGenerator.s.sol";
import "./GeneralConfig.s.sol";
import {IDeployScript} from "./interfaces/IDeployScript.sol";

abstract contract BaseDeploy is BaseScript {
  using StdStyle for string;

  bytes public constant EMPTY_ARGS = "";

  address internal _deployer;
  bool internal _alreadySetUp;
  bytes internal _overridenArgs;
  LogGenerator internal _logger;
  mapping(ContractKey contractKey => IDeployScript deployScript) internal _deployScript;

  modifier trySetUp() {
    if (!_alreadySetUp) {
      setUp();
      _alreadySetUp = true;
    }
    _;
  }

  function setUp() public virtual override {
    vm.pauseGasMetering();
    _alreadySetUp = true;
    super.setUp();

    _logger = new LogGenerator(vm, _config);
    _setUpDependencies();
  }

  function _setUpDependencies() internal virtual {}

  function _setDependencyDeployScript(ContractKey contractKey, address deployScript) internal {
    _deployScript[contractKey] = IDeployScript(deployScript);
  }

  function loadContractOrDeploy(ContractKey contractKey) public returns (address payable contractAddr) {
    string memory contractName = _config.getContractName(contractKey);
    try _config.getAddressFromCurrentNetwork(contractKey) returns (address payable addr) {
      contractAddr = addr;
    } catch {
      console2.log(string.concat("Deployment for ", contractName, " not found, try fresh deploy ...").yellow());
      contractAddr = _deployScript[contractKey].run();
    }
  }

  function setArgs(bytes memory args) public returns (IDeployScript) {
    _overridenArgs = args;
    return IDeployScript(address(this));
  }

  function arguments() public returns (bytes memory args) {
    args = _overridenArgs.length == 0 ? _defaultArguments() : _overridenArgs;
  }

  function _defaultArguments() internal virtual returns (bytes memory args) {}

  function _deployImmutable(ContractKey contractKey, bytes memory args) internal returns (address payable deployed) {
    string memory contractName = _config.getContractName(contractKey);
    string memory contractFilename = _config.getContractFileName(contractKey);
    uint256 nonce;
    (deployed, nonce) = _deployRaw(contractFilename, args);
    vm.label(deployed, contractName);

    _config.setAddress(_network, contractKey, deployed);
    _logger.generateDeploymentArtifact(_deployer, deployed, contractName, contractName, args, nonce);
  }

  function _upgradeProxy(ContractKey contractKey, bytes memory args) internal returns (address payable proxy) {
    string memory contractName = _config.getContractName(contractKey);
    string memory contractFilename = _config.getContractFileName(contractKey);

    uint256 logicNonce;
    address logic;
    (logic, logicNonce) = _deployRaw(contractFilename, EMPTY_ARGS);

    ProxyAdmin proxyAdmin = ProxyAdmin(_config.getAddressFromCurrentNetwork(ContractKey.ProxyAdmin));
    proxy = _config.getAddressFromCurrentNetwork(contractKey);
    _upgradeRaw(proxyAdmin, ITransparentUpgradeableProxy(proxy), logic, args);

    _logger.generateDeploymentArtifact(
      _deployer, logic, contractName, string.concat(contractName, "Logic"), EMPTY_ARGS, logicNonce
    );
  }

  function _deployProxy(ContractKey contractKey, bytes memory args) internal returns (address payable deployed) {
    string memory contractName = _config.getContractName(contractKey);
    string memory contractFilename = _config.getContractFileName(contractKey);
    (address logic, uint256 logicNonce) = _deployRaw(contractFilename, EMPTY_ARGS);

    uint256 proxyNonce;
    (deployed, proxyNonce) = _deployRaw(
      "TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy",
      abi.encode(logic, _config.getAddressFromCurrentNetwork(ContractKey.ProxyAdmin), args)
    );
    vm.label(deployed, contractName);

    _config.setAddress(_network, contractKey, deployed);
    _logger.generateDeploymentArtifact(
      _deployer, logic, contractName, string.concat(contractName, "Logic"), EMPTY_ARGS, logicNonce
    );
    _logger.generateDeploymentArtifact(
      _deployer, deployed, "TransparentUpgradeableProxy", string.concat(contractName, "Proxy"), args, proxyNonce
    );
  }

  function _deployRaw(string memory filename, bytes memory args)
    internal
    returns (address payable deployed, uint256 nonce)
  {
    nonce = vm.getNonce(_deployer);
    address expectedAddr = computeCreateAddress(_deployer, nonce);

    vm.resumeGasMetering();
    vm.broadcast(_deployer);
    deployed = payable(deployCode(filename, args));
    vm.pauseGasMetering();

    require(deployed == expectedAddr, "deployed != expectedAddr");
  }

  function _upgradeRaw(ProxyAdmin proxyAdmin, ITransparentUpgradeableProxy proxy, address logic, bytes memory args)
    internal
  {
    address owner = proxyAdmin.owner();

    vm.broadcast(owner);
    vm.resumeGasMetering();
    if (args.length == 0) proxyAdmin.upgradeAndCall(proxy, logic, "");
    else proxyAdmin.upgradeAndCall(proxy, logic, args);
    vm.pauseGasMetering();
  }
}
