// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { MockERC20 } from "forge-std/mocks/MockERC20.sol";
import { MockERC721 } from "forge-std/mocks/MockERC721.sol";
import { ProxyAdmin } from "@openzeppelin-v5/proxy/transparent/ProxyAdmin.sol";
import { BaseGeneralConfig } from "script/BaseGeneralConfig.sol";
import { DeployInfo, LibDeploy, LibProxy, ProxyInterface, UpgradeInfo } from "script/libraries/LibDeploy.sol";
import { vme } from "script/utils/Constants.sol";
import { RoninTransparentProxy } from "src/proxies/RoninTransparentProxy.sol";

contract LibDeployTest is Test {
  using LibProxy for *;

  function setUp() public {
    deployCodeTo("BaseGeneralConfig.sol:BaseGeneralConfig", abi.encode("", "deployments/"), 0, address(vme));
  }

  function testConcrete_Upgrade_ProxyWithAdminIsEOA() public {
    address eoa = makeAddr("eoa");
    address logic = address(new MockERC721());
    vm.label(logic, "Logic");
    address proxy = address(new RoninTransparentProxy(logic, eoa, ""));
    vm.label(proxy, "Proxy");

    UpgradeInfo memory info = UpgradeInfo({
      proxy: proxy,
      logic: logic,
      callValue: 0,
      callData: abi.encodeCall(MockERC721.initialize, ("Name", "Symbol")),
      proxyInterface: ProxyInterface.Transparent,
      upgradeCallback: emptyFn,
      shouldPrompt: false,
      shouldUseCallback: false
    });

    info.upgrade();
  }

  function testConcrete_Upgrade_ProxyWithAdminIsProxyAdmin() public {
    address owner = makeAddr("owner");
    vm.prank(owner);
    address proxyAdmin = address(new ProxyAdmin(owner));
    vm.label(proxyAdmin, "ProxyAdmin");

    address logic = address(new MockERC20());
    vm.label(logic, "Logic");
    address proxy = address(new RoninTransparentProxy(logic, proxyAdmin, ""));
    vm.label(proxy, "Proxy");

    UpgradeInfo memory info = UpgradeInfo({
      proxy: proxy,
      logic: logic,
      callValue: 0,
      callData: abi.encodeCall(MockERC20.initialize, ("Name", "Symbol", 18)),
      proxyInterface: ProxyInterface.Transparent,
      upgradeCallback: emptyFn,
      shouldPrompt: false,
      shouldUseCallback: false
    });

    info.upgrade();
  }

  function testConcrete_Upgrade_ProxyWithAdminIsMultiSig() public {
    address multisig = makeAddr("multisig");
    vm.etch(multisig, type(MockERC20).runtimeCode);

    address logic = address(new MockERC20());
    vm.label(logic, "Logic");
    address proxy = address(new RoninTransparentProxy(logic, multisig, ""));
    vm.label(proxy, "Proxy");

    UpgradeInfo memory info = UpgradeInfo({
      proxy: proxy,
      logic: logic,
      callValue: 0,
      callData: abi.encodeCall(MockERC20.initialize, ("Name", "Symbol", 18)),
      proxyInterface: ProxyInterface.Transparent,
      upgradeCallback: emptyFn,
      shouldPrompt: false,
      shouldUseCallback: false
    });

    info.upgrade();
  }

  function testConcrete_Upgrade_ProxyWithAdminIsProxyAdmin_ButOwnerOfProxyAdminIsMultisig() external {
    address multisig = makeAddr("multisig");
    vm.etch(multisig, type(MockERC20).runtimeCode);
    vm.prank(multisig);
    address proxyAdmin = address(new ProxyAdmin(multisig));
    assertTrue(ProxyAdmin(proxyAdmin).owner() == multisig, "Owner of ProxyAdmin is not multisig");
    vm.label(proxyAdmin, "ProxyAdmin");

    address logic = address(new MockERC20());
    vm.label(logic, "Logic");
    address proxy = address(new RoninTransparentProxy(logic, proxyAdmin, ""));
    vm.label(proxy, "Proxy");

    console.log("ProxyAdmin: ", proxy.getProxyAdmin());

    UpgradeInfo memory info = UpgradeInfo({
      proxy: proxy,
      logic: logic,
      callValue: 0,
      callData: abi.encodeCall(MockERC20.initialize, ("Name", "Symbol", 18)),
      proxyInterface: ProxyInterface.Transparent,
      upgradeCallback: emptyFn,
      shouldPrompt: false,
      shouldUseCallback: false
    });

    info.upgrade();
  }

  function emptyFn(
    address, /* proxy */
    address, /* logic */
    uint256, /* callValue */
    bytes memory, /* callData */
    ProxyInterface /* proxyInterface */
  ) internal { }
}
