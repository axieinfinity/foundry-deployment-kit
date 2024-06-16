// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { LibString } from "../dependencies/solady-0.0.206/src/utils/LibString.sol";
import { console } from "../dependencies/forge-std-1.8.2/src/console.sol";
import { StdStyle } from "../dependencies/forge-std-1.8.2/src/StdStyle.sol";
import { ScriptExtended, IScriptExtended } from "./extensions/ScriptExtended.s.sol";
import { OnchainExecutor } from "./OnchainExecutor.s.sol"; // cheat to load artifact to parent `out` directory
import { IMigrationScript } from "./interfaces/IMigrationScript.sol";
import { LibProxy } from "./libraries/LibProxy.sol";
import { DefaultContract } from "./utils/DefaultContract.sol";
import { ProxyInterface, LibDeploy, DeployInfo, UpgradeInfo } from "./libraries/LibDeploy.sol";
import { cheatBroadcast } from "./utils/Helpers.sol";
import { TContract, TNetwork } from "./types/Types.sol";

abstract contract BaseMigration is ScriptExtended {
  using StdStyle for *;
  using LibString for bytes32;
  using LibProxy for address payable;

  bytes internal _overriddenArgs;
  mapping(TContract contractType => IMigrationScript deployScript) internal _deployScript;

  function setUp() public virtual override {
    super.setUp();
    _storeRawSharedArguments();
    _injectDependencies();
  }

  function upgradeCallback(
    address, /* proxy */
    address, /* logic */
    uint256, /* callValue */
    bytes memory, /* callData */
    ProxyInterface /* proxyInterface */
  ) external virtual { }

  function _sharedArguments() internal virtual returns (bytes memory rawSharedArgs);

  function _injectDependencies() internal virtual { }

  function _defaultArguments() internal virtual returns (bytes memory) { }

  function switchTo(TNetwork networkType, uint256 forkBlockNumber)
    public
    virtual
    override
    returns (TNetwork currNetwork, uint256 currForkId)
  {
    (currNetwork, currForkId) = super.switchTo(networkType, forkBlockNumber);
    // Should rebuild the shared arguments since different chain may have different shared arguments
    _storeRawSharedArguments();
    // Should rebuild runtime config since different chain may have different runtime config
    vme.buildRuntimeConfig();
    // Should rebuild the contract data since different chain may have different contract data
    vme.setUpDefaultContracts();
    // Log Sender Info of current network
    vme.logSenderInfo();
  }

  function loadContractOrDeploy(TContract contractType) public virtual returns (address payable contractAddr) {
    string memory contractName = CONFIG.getContractName(contractType);
    try this.loadContract(contractType) returns (address payable addr) {
      contractAddr = addr;
    } catch {
      console.log(string.concat("Deployment for ", contractName, " not found, try fresh deploy ...").yellow());
      contractAddr = _deployScript[contractType].run();
    }
  }

  function _storeRawSharedArguments() internal virtual {
    vme.setRawSharedArguments(_sharedArguments());
  }

  function overrideArgs(bytes memory args) public virtual returns (IMigrationScript) {
    _overriddenArgs = args;
    return IMigrationScript(address(this));
  }

  function arguments() public virtual returns (bytes memory args) {
    args = _overriddenArgs.length == 0 ? _defaultArguments() : _overriddenArgs;
  }

  function _cheatBroadcast(address from, address to, bytes memory callData) internal virtual {
    cheatBroadcast(from, to, 0, callData);
  }

  function _getProxyAdmin() internal virtual returns (address payable proxyAdmin) {
    proxyAdmin = loadContract(DefaultContract.ProxyAdmin.key());
  }

  function _deployImmutable(TContract contractType) internal virtual returns (address payable deployed) {
    deployed = _deployImmutable({
      contractType: contractType,
      artifactName: vme.getContractName(contractType),
      by: sender(),
      value: 0,
      args: arguments()
    });
  }

  function _deployImmutable(TContract contractType, bytes memory args)
    internal
    virtual
    returns (address payable deployed)
  {
    deployed = _deployImmutable({
      contractType: contractType,
      artifactName: vme.getContractName(contractType),
      by: sender(),
      value: 0,
      args: args
    });
  }

  function _deployImmutable(
    TContract contractType,
    string memory artifactName,
    address by,
    uint256 value,
    bytes memory args
  )
    internal
    virtual
    logFn(string.concat("_deployImmutable ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable deployed)
  {
    string memory contractName = vme.getContractName(contractType);

    deployed = DeployInfo({
      callValue: value,
      by: by,
      contractName: contractName,
      absolutePath: vme.getContractAbsolutePath(contractType),
      artifactName: bytes(artifactName).length == 0 ? contractName : artifactName,
      constructorArgs: args
    }).deployFromArtifact();

    vme.setAddress(network(), contractType, deployed);
  }

  function _deployLogic(TContract contractType) internal virtual returns (address payable logic) {
    logic = _deployLogic({
      contractType: contractType,
      artifactName: vme.getContractName(contractType),
      by: sender(),
      constructorArgs: arguments()
    });
  }

  function _deployLogic(TContract contractType, bytes memory args) internal virtual returns (address payable logic) {
    logic = _deployLogic({
      contractType: contractType,
      artifactName: vme.getContractName(contractType),
      by: sender(),
      constructorArgs: args
    });
  }

  function _deployLogic(TContract contractType, string memory artifactName, address by, bytes memory constructorArgs)
    internal
    virtual
    logFn(string.concat("_deployLogic ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable logic)
  {
    string memory contractName = vme.getContractName(contractType);

    logic = DeployInfo({
      callValue: 0,
      by: by,
      contractName: contractName,
      absolutePath: vme.getContractAbsolutePath(contractType),
      artifactName: bytes(artifactName).length == 0 ? contractName : artifactName,
      constructorArgs: constructorArgs
    }).deployImplementation();
  }

  function _deployProxy(TContract contractType) internal virtual returns (address payable deployed) {
    deployed = _deployProxy(contractType, arguments());
  }

  function _deployProxy(TContract contractType, bytes memory callData)
    internal
    virtual
    returns (address payable deployed)
  {
    deployed = _deployProxy({
      contractType: contractType,
      artifactName: vme.getContractName(contractType),
      proxyAdmin: _getProxyAdmin(),
      callValue: 0,
      by: sender(),
      callData: callData,
      logicConstructorArgs: EMPTY_ARGS
    });
  }

  function _deployProxy(TContract contractType, bytes memory callData, bytes memory logicConstructorArgs)
    internal
    virtual
    returns (address payable deployed)
  {
    deployed = _deployProxy({
      contractType: contractType,
      artifactName: vme.getContractName(contractType),
      proxyAdmin: _getProxyAdmin(),
      callValue: 0,
      by: sender(),
      callData: callData,
      logicConstructorArgs: logicConstructorArgs
    });
  }

  function _deployProxy(
    TContract contractType,
    string memory artifactName,
    address proxyAdmin,
    uint256 callValue,
    address by,
    bytes memory callData,
    bytes memory logicConstructorArgs
  )
    internal
    virtual
    logFn(string.concat("_deployProxy ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable deployed)
  {
    string memory contractName = vme.getContractName(contractType);

    deployed = LibDeploy.deployTransparentProxy({
      implInfo: DeployInfo({
        callValue: 0,
        by: by,
        contractName: contractName,
        absolutePath: vme.getContractAbsolutePath(contractType),
        artifactName: bytes(artifactName).length == 0 ? contractName : artifactName,
        constructorArgs: logicConstructorArgs
      }),
      callValue: callValue,
      proxyAdmin: proxyAdmin,
      callData: callData
    });

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
    proxy = loadContract(contractType);
    address logic = _deployLogic(contractType, argsLogicConstructor);

    UpgradeInfo({
      proxy: proxy,
      logic: logic,
      callValue: 0,
      callData: args,
      shouldPrompt: true,
      proxyInterface: ProxyInterface.Transparent,
      upgradeCallback: this.upgradeCallback,
      shouldUseCallback: false
    }).upgrade();
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
