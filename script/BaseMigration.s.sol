// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ProxyAdmin } from "../lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {
  ITransparentUpgradeableProxy,
  TransparentUpgradeableProxy
} from "../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { LibString } from "../lib/solady/src/utils/LibString.sol";
import {
  console,
  StdStyle,
  stdStorage,
  StdStorage,
  ScriptExtended,
  IScriptExtended,
  LibSharedAddress
} from "./extensions/ScriptExtended.s.sol";
import { IArtifactFactory, ArtifactFactory } from "./ArtifactFactory.sol";
import { OnchainExecutor } from "./OnchainExecutor.s.sol"; // cheat to load artifact to parent `out` directory
import { IMigrationScript } from "./interfaces/IMigrationScript.sol";
import { LibProxy } from "./libraries/LibProxy.sol";
import { DefaultContract } from "./utils/DefaultContract.sol";
import { TContract } from "./types/Types.sol";

abstract contract BaseMigration is ScriptExtended {
  using StdStyle for *;
  using LibString for bytes32;
  using LibProxy for address payable;

  IArtifactFactory public constant ARTIFACT_FACTORY = IArtifactFactory(LibSharedAddress.ARTIFACT_FACTORY);

  bytes internal _overriddenArgs;
  mapping(TContract contractType => IMigrationScript deployScript) internal _deployScript;

  function setUp() public virtual override {
    super.setUp();
    _storeRawSharedArguments();
    _injectDependencies();
    deploySharedAddress(address(ARTIFACT_FACTORY), type(ArtifactFactory).creationCode, "ArtifactFactory");
  }

  function _storeRawSharedArguments() internal virtual {
    if (CONFIG.areSharedArgumentsStored()) return;
    CONFIG.setRawSharedArguments(_sharedArguments());
  }

  function _sharedArguments() internal virtual returns (bytes memory rawSharedArgs);

  function _injectDependencies() internal virtual { }

  function _defaultArguments() internal virtual returns (bytes memory) { }

  function loadContractOrDeploy(TContract contractType) public virtual returns (address payable contractAddr) {
    string memory contractName = CONFIG.getContractName(contractType);
    try this.loadContract(contractType) returns (address payable addr) {
      contractAddr = addr;
    } catch {
      console.log(string.concat("Deployment for ", contractName, " not found, try fresh deploy ...").yellow());
      contractAddr = _deployScript[contractType].run();
    }
  }

  function loadContract(TContract contractType) public view virtual returns (address payable contractAddr) {
    return CONFIG.getAddressFromCurrentNetwork(contractType);
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
    logic = _deployLogic(contractType, EMPTY_ARGS);
  }

  function _deployLogic(TContract contractType, bytes memory args)
    internal
    virtual
    logFn(string.concat("_deployLogic ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable logic)
  {
    string memory contractName = CONFIG.getContractName(contractType);
    string memory contractAbsolutePath = CONFIG.getContractAbsolutePath(contractType);

    uint256 logicNonce;
    (logic, logicNonce) = _deployRaw(contractAbsolutePath, args);
    CONFIG.label(block.chainid, logic, string.concat(contractName, "::Logic"));
    ARTIFACT_FACTORY.generateArtifact(
      sender(), logic, contractAbsolutePath, string.concat(contractName, "Logic"), args, logicNonce
    );
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
    string memory contractName = CONFIG.getContractName(contractType);

    address logic = _deployLogic(contractType, argsLogicConstructor);
    string memory proxyAbsolutePath =
      "./out/transparent/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json";
    uint256 proxyNonce = vm.getNonce(sender());
    address proxyAdmin = _getProxyAdmin();
    assertTrue(proxyAdmin != address(0x0), "BaseMigration: Null ProxyAdmin");

    vm.broadcast(sender());
    deployed = payable(address(new TransparentUpgradeableProxy(logic, proxyAdmin, args)));

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
    proxy = CONFIG.getAddress(network(), contractType);
    _upgradeRaw(proxy.getProxyAdmin(), proxy, logic, args);
  }

  function _mockUpgradeRaw(address proxyAdmin, address payable proxy, address logic, bytes memory args)
    internal
    virtual
  {
    ITransparentUpgradeableProxy iProxy = ITransparentUpgradeableProxy(proxy);
    ProxyAdmin wProxyAdmin = ProxyAdmin(proxyAdmin);
    // if proxyAdmin is External Owned Wallet
    if (proxyAdmin.code.length == 0) {
      vm.prank(proxyAdmin);
      if (args.length == 0) iProxy.upgradeTo(logic);
      else iProxy.upgradeToAndCall(logic, args);
    } else {
      try wProxyAdmin.owner() returns (address owner) {
        if (args.length == 0) {
          // try `upgrade` function
          vm.prank(owner);
          (bool success,) = proxyAdmin.call(abi.encodeCall(ProxyAdmin.upgrade, (iProxy, logic)));
          if (success) {
            vm.prank(owner);
            wProxyAdmin.upgrade(iProxy, logic);
          } else {
            console.log(
              StdStyle.yellow(
                "`ProxyAdmin:upgrade` failed!. Retrying with `ProxyAdmin:upgradeAndCall` with emty args..."
              )
            );
            vm.prank(owner);
            wProxyAdmin.upgradeAndCall(iProxy, logic, args);
          }
        } else {
          vm.prank(owner);
          wProxyAdmin.upgradeAndCall(iProxy, logic, args);
        }
      } catch {
        revert("BaseMigration: Unknown ProxyAdmin contract!");
      }
    }
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
      vm.broadcast(proxyAdmin);
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
              vm.broadcast(owner);
              wProxyAdmin.upgrade(iProxy, logic);
            }
          } else {
            console.log(
              "`ProxyAdmin:upgrade` failed!. Retrying with `ProxyAdmin:upgradeAndCall` with emty args...".yellow()
            );
            if (owner.code.length != 0) {
              _cheatUpgradeAndCall(owner, wProxyAdmin, iProxy, logic, args);
            } else {
              vm.broadcast(owner);
              wProxyAdmin.upgradeAndCall(iProxy, logic, args);
            }
          }
        } else {
          if (owner.code.length != 0) {
            _cheatUpgradeAndCall(owner, wProxyAdmin, iProxy, logic, args);
          } else {
            vm.broadcast(owner);
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
    _deployScript[contractType] = IMigrationScript(address(deployScript));
  }

  function _setDependencyDeployScript(TContract contractType, address deployScript) internal virtual {
    _deployScript[contractType] = IMigrationScript(deployScript);
  }
}
