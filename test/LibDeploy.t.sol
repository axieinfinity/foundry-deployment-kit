// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ProxyInterface, UpgradeInfo, DeployInfo, LibDeploy, LibProxy } from "script/libraries/LibDeploy.sol";
import { vme } from "script/utils/Constants.sol";
import { BaseGeneralConfig } from "script/BaseGeneralConfig.sol";
import { Test } from "../dependencies/forge-std-1.8.2/src/Test.sol";
import { console } from "../dependencies/forge-std-1.8.2/src/console.sol";
import { TransparentProxyOZv4_9_5 } from "src/TransparentProxyOZv4_9_5.sol";
import { MockERC721 } from "../dependencies/forge-std-1.8.2/src/mocks/MockERC721.sol";
import { MockERC20 } from "../dependencies/forge-std-1.8.2/src/mocks/MockERC20.sol";
import { ProxyAdmin } from "../dependencies/@openzeppelin-contracts-4.9.3/proxy/transparent/ProxyAdmin.sol";

contract LibDeployTest is Test {
  using LibProxy for *;

  function setUp() public {
    deployCodeTo("BaseGeneralConfig.sol:BaseGeneralConfig", abi.encode("", "deployments/"), 0, address(vme));
  }

  function testConcrete_Upgrade_ProxyWithAdminIsEOA() public {
    address eoa = makeAddr("eoa");
    address logic = address(new MockERC721());
    vm.label(logic, "Logic");
    address proxy = address(new TransparentProxyOZv4_9_5(logic, eoa, ""));
    vm.label(proxy, "Proxy");

    UpgradeInfo memory info = UpgradeInfo({
      proxy: proxy,
      logic: logic,
      callValue: 0,
      callData: abi.encodeCall(MockERC721.initialize, ("Name", "Symbol")),
      proxyInterface: ProxyInterface.Transparent,
      upgradeCallback: this.emptyFn,
      shouldPrompt: false,
      shouldUseCallback: false
    });

    info.upgrade();
  }

  function testConcrete_Upgrade_ProxyWithAdminIsProxyAdmin() public {
    address owner = makeAddr("owner");
    vm.prank(owner);
    address proxyAdmin = address(new ProxyAdmin());
    vm.label(proxyAdmin, "ProxyAdmin");

    address logic = address(new MockERC20());
    vm.label(logic, "Logic");
    address proxy = address(new TransparentProxyOZv4_9_5(logic, proxyAdmin, ""));
    vm.label(proxy, "Proxy");

    UpgradeInfo memory info = UpgradeInfo({
      proxy: proxy,
      logic: logic,
      callValue: 0,
      callData: abi.encodeCall(MockERC20.initialize, ("Name", "Symbol", 18)),
      proxyInterface: ProxyInterface.Transparent,
      upgradeCallback: this.emptyFn,
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
    address proxy = address(new TransparentProxyOZv4_9_5(logic, multisig, ""));
    vm.label(proxy, "Proxy");

    UpgradeInfo memory info = UpgradeInfo({
      proxy: proxy,
      logic: logic,
      callValue: 0,
      callData: abi.encodeCall(MockERC20.initialize, ("Name", "Symbol", 18)),
      proxyInterface: ProxyInterface.Transparent,
      upgradeCallback: this.emptyFn,
      shouldPrompt: false,
      shouldUseCallback: false
    });

    info.upgrade();
  }

  function testConcrete_Upgrade_ProxyWithAdminIsProxyAdmin_ButOwnerOfProxyAdminIsMultisig() external {
    address multisig = makeAddr("multisig");
    vm.etch(multisig, type(MockERC20).runtimeCode);
    vm.prank(multisig);
    address proxyAdmin = address(new ProxyAdmin());
    assertTrue(ProxyAdmin(proxyAdmin).owner() == multisig, "Owner of ProxyAdmin is not multisig");
    vm.label(proxyAdmin, "ProxyAdmin");

    address logic = address(new MockERC20());
    vm.label(logic, "Logic");
    address proxy = address(new TransparentProxyOZv4_9_5(logic, proxyAdmin, ""));
    vm.label(proxy, "Proxy");

    console.log("ProxyAdmin: ", proxy.getProxyAdmin());

    UpgradeInfo memory info = UpgradeInfo({
      proxy: proxy,
      logic: logic,
      callValue: 0,
      callData: abi.encodeCall(MockERC20.initialize, ("Name", "Symbol", 18)),
      proxyInterface: ProxyInterface.Transparent,
      upgradeCallback: this.emptyFn,
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
  ) external { }
}
