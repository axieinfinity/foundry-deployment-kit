// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ITransparentUpgradeableProxy } from
  "../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "../lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import { LibString } from "../lib/solady/src/utils/LibString.sol";
import { console } from "../lib/forge-std/src/console.sol";
import { StdStyle } from "../lib/forge-std/src/StdStyle.sol";
import { ScriptExtended, IScriptExtended } from "./extensions/ScriptExtended.s.sol";
import { OnchainExecutor } from "./OnchainExecutor.s.sol"; // cheat to load artifact to parent `out` directory
import { IMigrationScript } from "./interfaces/IMigrationScript.sol";
import { LibProxy } from "./libraries/LibProxy.sol";
import { loadContract } from "./utils/Helpers.sol";
import { DefaultContract } from "./utils/DefaultContract.sol";
import { LibDeploy, DeploymentInfo } from "./libraries/LibDeploy.sol";
import { LibErrorHandler } from "../lib/contract-libs/src/LibErrorHandler.sol";
import { TContract, TNetwork } from "./types/Types.sol";

abstract contract BaseMigration is ScriptExtended {
  using StdStyle for *;
  using LibString for bytes32;
  using LibErrorHandler for bool;
  using LibProxy for address payable;

  bytes internal _overriddenArgs;
  mapping(TContract contractType => IMigrationScript deployScript) internal _deployScript;

  function setUp() public virtual override {
    super.setUp();
    _storeRawSharedArguments();
    _injectDependencies();
  }

  function switchTo(TNetwork networkType, uint256 forkBlockNumber)
    public
    virtual
    override
    returns (TNetwork currNetwork, uint256 currForkId)
  {
    (currNetwork, currForkId) = super.switchTo(networkType, forkBlockNumber);
    // Should rebuild the shared arguments since different chain may have different shared arguments
    _storeRawSharedArguments();
    // Should rebuild runtime config
    vme.buildRuntimeConfig();
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

  function _sharedArguments() internal virtual returns (bytes memory rawSharedArgs);

  function _injectDependencies() internal virtual { }

  function _defaultArguments() internal virtual returns (bytes memory) { }

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
    string memory contractName = vme.getContractName(contractType);

    deployed = DeploymentInfo({
      callValue: 0,
      by: sender(),
      contractName: contractName,
      absolutePath: vme.getContractAbsolutePath(contractType),
      artifactName: contractName,
      constructorArgs: arguments()
    }).deployFromArtifact();

    vme.setAddress(network(), contractType, deployed);
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

  function _deployLogic(TContract contractType)
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
      constructorArgs: EMPTY_ARGS
    }).deployImplementation();
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
    // address logic = _deployLogic(contractType, argsLogicConstructor);
    // proxy = vme.getAddress(network(), contractType);
    // _upgradeRaw(proxy.getProxyAdmin(), proxy, logic, args);

    revert("Unimplemented");
  }

  function _cheatBroadcast(address from, address to, bytes memory callData) internal virtual {
    string[] memory commandInputs = new string[](3);
    commandInputs[0] = "cast";
    commandInputs[1] = "4byte-decode";
    commandInputs[2] = vm.toString(callData);
    string memory decodedCallData = string(vm.ffi(commandInputs));

    console.log("\n");
    console.log("--------------------------- Call Detail ---------------------------");
    console.log("To:".cyan(), vm.getLabel(to));
    console.log(
      "Raw Calldata Data (Please double check using `cast pretty-calldata {raw_bytes}`):\n".cyan(),
      string.concat(" - ", vm.toString(callData))
    );
    console.log("Cast Decoded Call Data:".cyan(), decodedCallData);
    console.log("--------------------------------------------------------------------");

    vm.prank(from);
    (bool success, bytes memory returnOrRevertData) = to.call(callData);
    success.handleRevert(bytes4(callData), returnOrRevertData);
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
