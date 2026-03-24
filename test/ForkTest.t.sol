// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ForkTest } from "./ForkTest.sol";

import { TContract } from "script/types/TContract.sol";
import { DefaultContract } from "script/utils/DefaultContract.sol";
import { DefaultNetwork } from "script/utils/DefaultNetwork.sol";
import { LibProxy } from "script/libraries/LibProxy.sol";

import { SampleProxy } from "src/mocks/SampleProxy.sol";

/**
 * @dev Demonstrates the lightweight ForkTest pattern.
 *
 * This test compiles ONLY:
 * - forge-std/Test + forge-std/Base
 * - AddressBook (~95 lines, imports: types + solady/LibString + DefaultNetwork)
 * - Deployer (~130 lines, imports: LibProxy + forge-std/Base)
 * - The tested contract (SampleProxy)
 *
 * It does NOT compile:
 * - BaseMigration / ScriptExtended
 * - BaseGeneralConfig / VME / 6 config mixins
 * - RuntimeConfig / WalletConfig / ContractConfig / NetworkConfig / MigrationConfig / UserDefinedConfig
 * - LibInitializeGuard / LibArtifact
 * - RoninTransparentProxy / TransparentProxyOZv4_9_5 source (uses artifact)
 */
contract ForkTestDemo is ForkTest {
  using LibProxy for address;

  SampleProxy proxy;
  address proxyAdmin;

  function setUp() public {
    _setUpLocal();

    proxyAdmin = makeAddr("proxyAdmin");

    proxy = SampleProxy(
      _deployAndRegister(
        DefaultContract.ProxyAdmin.key(),
        "SampleProxy.sol:SampleProxy",
        proxyAdmin,
        abi.encodeCall(SampleProxy.initialize, ("hello"))
      )
    );
  }

  function testConcrete_DeployBehindProxy() public view {
    assertEq(proxy.getMessage(), "hello");
    assertEq(address(proxy).getProxyAdmin(), proxyAdmin);
  }

  function testConcrete_UpgradeProxy() public {
    address newLogic = address(new SampleProxy());

    _upgradeProxy(
      address(proxy), newLogic, abi.encodeCall(SampleProxy.initializeV2, ())
    );

    assertEq(proxy.getMessage(), "hello");
  }

  function testConcrete_AddressBook_SetAndGet() public {
    address mockAddr = makeAddr("mock-contract");
    TContract mockType = TContract.wrap(bytes32("mock"));

    setAddress(getCurrentNetwork(), mockType, mockAddr);
    assertEq(getAddressFromCurrentNetwork(mockType), mockAddr);
  }
}
