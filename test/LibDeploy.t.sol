// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ProxyInterface, UpgradeInfo, DeployInfo, LibDeploy } from "script/libraries/LibDeploy.sol";
import { vme } from "script/utils/Constants.sol";
import { BaseGeneralConfig } from "script/BaseGeneralConfig.sol";
import { Test } from "../lib/forge-std/src/Test.sol";
import { TransparentProxyOZv4_9_5 } from "src/TransparentProxyOZv4_9_5.sol";
import { MockERC721 } from "../lib/forge-std/src/mocks/MockERC721.sol";
import { MockERC20 } from "../lib/forge-std/src/mocks/MockERC20.sol";
import { ProxyAdmin } from "../lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

contract LibDeployTest is Test {
  function setUp() public {
    deployCodeTo("BaseGeneralConfig.sol:BaseGeneralConfig", abi.encode("", "deployments/"), 0, address(vme));
  }

  function test_Upgrade_ProxyWithAdminIsEOA() public {
    vm.skip(true);
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
      shouldUseCallback: false
    });

    info.upgrade();
  }

  function test_Upgrade_ProxyWithAdminIsProxyAdmin() public {
    vm.skip(true);
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
      shouldUseCallback: false
    });

    info.upgrade();
  }

  function test_Upgrade_ProxyWithAdminIsMultiSig() public {
    vm.skip(true);
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
      shouldUseCallback: false
    });

    info.upgrade();
  }

  function test_Upgrade_ProxyWithAdminIsProxyAdmin_ButOwnerOfProxyAdminIsMultisig() external {
    vm.skip(true);
    address multisig = makeAddr("multisig");
    vm.etch(multisig, type(ProxyAdmin).runtimeCode);
    vm.prank(multisig);
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
      shouldUseCallback: false
    });

    info.upgrade();
  }

  function emptyFn() external { }
}
