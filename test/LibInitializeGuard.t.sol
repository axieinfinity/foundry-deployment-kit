// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { StdStyle } from "../dependencies/forge-std-1.9.3/src/StdStyle.sol";
import { Test } from "../dependencies/forge-std-1.9.3/src/Test.sol";
import { console } from "../dependencies/forge-std-1.9.3/src/console.sol";

import { Initializable } from "../dependencies/openzeppelin-v4-4.9.5/contracts/proxy/utils/Initializable.sol";

import { MockConfig } from "./MockConfig.sol";
import { BaseGeneralConfig } from "script/BaseGeneralConfig.sol";
import { BaseMigration } from "script/BaseMigration.s.sol";
import { LibInitializeGuard } from "script/libraries/LibInitializeGuard.sol";
import { LibProxy } from "script/libraries/LibProxy.sol";
import { SampleProxyDeploy } from "script/sample/contracts/SampleProxyDeploy.s.sol";
import { Vm, vme } from "script/utils/Constants.sol";

import { SampleProxyForTestingPurpose2 } from "src/mocks/ForTesting/SampleProxyForTestingPurpose2.sol";
import { SampleProxyForTestingPurpose5 } from "src/mocks/ForTesting/SampleProxyForTestingPurpose5.sol";
import { SampleProxyForTestingPurpose6 } from "src/mocks/ForTesting/SampleProxyForTestingPurpose6.sol";
import { SampleProxyForTestingPurpose7 } from "src/mocks/ForTesting/SampleProxyForTestingPurpose7.sol";
import { SampleProxy } from "src/mocks/SampleProxy.sol";

interface ITransparentUpgradeableProxy {
	function upgradeTo(address) external;
  function upgradeToAndCall(address, bytes memory) external payable;
}

contract ValidateWrapper {
  function runValidate(Vm.Log[] memory logs, Vm.AccountAccess[] memory stateDiffs) public {
    LibInitializeGuard.validate(logs, stateDiffs);
  }
}

contract LibInitializeGuardTest is Test {
  using LibProxy for address;
  using StdStyle for *;

  SampleProxy _sample;

  function setUp() public {
    deployCodeTo("MockConfig.sol:MockConfig", abi.encode(""), 0, address(vme));
  }

  function testConcrete_DeployProxy_ForTheFirstTime() public {
    MockConfig(address(vme)).updateSampleProxyLogicForTesting("SampleProxyForTestingPurpose4");

    vm.recordLogs();
    vm.startStateDiffRecording();

    _sample = new SampleProxyDeploy().run();

    Vm.Log[] memory logs = vm.getRecordedLogs();
    Vm.AccountAccess[] memory stateDiffs = vm.stopAndReturnStateDiff();

    LibInitializeGuard.validate(logs, stateDiffs);
  }

  function testConcrete_Upgrade_WithoutInitialization() public {
    testConcrete_DeployProxy_ForTheFirstTime();
    _sample = new SampleProxyDeploy().run();
    address admin = address(_sample).getProxyAdmin();

    vm.recordLogs();
    vm.startStateDiffRecording();

    address newLogic = address(new SampleProxyForTestingPurpose2());
    vm.prank(admin);
    ITransparentUpgradeableProxy(address(_sample)).upgradeTo(newLogic);
    MockConfig(address(vme)).updateSampleProxyLogicForTesting("SampleProxyForTestingPurpose2");

    Vm.Log[] memory logs = vm.getRecordedLogs();
    Vm.AccountAccess[] memory stateDiffs = vm.stopAndReturnStateDiff();

    LibInitializeGuard.validate(logs, stateDiffs);
  }

  function testConcrete_UpgradeFrom_V1_To_V2_ByCallingInitializeV2() public {
    MockConfig(address(vme)).updateSampleProxyLogicForTesting("SampleProxyForTestingPurpose4");

    _sample = new SampleProxyDeploy().run();
    address admin = address(_sample).getProxyAdmin();
    bytes memory callData = abi.encodeCall(SampleProxyForTestingPurpose5.initializeV2, (100));

    vm.recordLogs();
    vm.startStateDiffRecording();

    address newLogic = address(new SampleProxyForTestingPurpose5());
    vm.prank(admin);
    ITransparentUpgradeableProxy(address(_sample)).upgradeToAndCall(newLogic, callData);
    MockConfig(address(vme)).updateSampleProxyLogicForTesting("SampleProxyForTestingPurpose5");

    Vm.Log[] memory logs = vm.getRecordedLogs();
    Vm.AccountAccess[] memory stateDiffs = vm.stopAndReturnStateDiff();

    LibInitializeGuard.validate(logs, stateDiffs);
  }

  function testConcrete_UpgradeFrom_V2_To_V3_ByCallingInitializeV3() public {
    testConcrete_UpgradeFrom_V1_To_V2_ByCallingInitializeV2();
    address admin = address(_sample).getProxyAdmin();
    bytes memory callData = abi.encodeCall(SampleProxyForTestingPurpose6.initializeV3, (100));

    vm.recordLogs();
    vm.startStateDiffRecording();

    address newLogic = address(new SampleProxyForTestingPurpose6());
    vm.prank(admin);
    ITransparentUpgradeableProxy(address(_sample)).upgradeToAndCall(newLogic, callData);
    MockConfig(address(vme)).updateSampleProxyLogicForTesting("SampleProxyForTestingPurpose6");

    Vm.Log[] memory logs = vm.getRecordedLogs();
    Vm.AccountAccess[] memory stateDiffs = vm.stopAndReturnStateDiff();

    LibInitializeGuard.validate(logs, stateDiffs);
  }

  function testRevert_When_UpgradeFrom_V3_To_V5_ByCallingInitilizeV5() public {
    testConcrete_UpgradeFrom_V2_To_V3_ByCallingInitializeV3();
    address admin = address(_sample).getProxyAdmin();
    bytes memory callData = abi.encodeCall(SampleProxyForTestingPurpose7.initializeV5, (100));

    vm.recordLogs();
    vm.startStateDiffRecording();

    address newLogic = address(new SampleProxyForTestingPurpose7());
    vm.prank(admin);
    ITransparentUpgradeableProxy(address(_sample)).upgradeToAndCall(newLogic, callData);
    MockConfig(address(vme)).updateSampleProxyLogicForTesting("SampleProxyForTestingPurpose7");

    Vm.Log[] memory logs = vm.getRecordedLogs();
    Vm.AccountAccess[] memory stateDiffs = vm.stopAndReturnStateDiff();

    ValidateWrapper _wrapper = new ValidateWrapper();
    vm.expectRevert("LibInitializeGuard: Version does not correctly increment!");
    _wrapper.runValidate(logs, stateDiffs);
  }

  function testRevert_When_FoundFourInitializeFunctions_But_ActualInitVerIsOne() public {
    vm.recordLogs();
    vm.startStateDiffRecording();

    _sample = new SampleProxyDeploy().run();

    Vm.Log[] memory logs = vm.getRecordedLogs();
    Vm.AccountAccess[] memory stateDiffs = vm.stopAndReturnStateDiff();

    ValidateWrapper _wrapper = new ValidateWrapper();
    vm.expectRevert(bytes(string.concat("LibInitializeGuard: Invalid initialized version! Expected: 4 Got: 1")));
    _wrapper.runValidate(logs, stateDiffs);
  }

  function testRevert_When_NotDisableInitializedVersion() public {
    MockConfig(address(vme)).updateSampleProxyLogicForTesting("SampleProxyForTestingPurpose");

    vm.recordLogs();
    vm.startStateDiffRecording();

    _sample = new SampleProxyDeploy().run();

    Vm.Log[] memory logs = vm.getRecordedLogs();
    Vm.AccountAccess[] memory stateDiffs = vm.stopAndReturnStateDiff();

    ValidateWrapper _wrapper = new ValidateWrapper();
    vm.expectRevert(
      bytes(
        string.concat(
          "LibInitializeGuard: Logic ",
          vm.getLabel(address(_sample).getProxyImplementation()),
          " did not disable initialized version!"
        )
      )
    );
    _wrapper.runValidate(logs, stateDiffs);
  }

  function testRevert_When_ProxyDoesNot_Initialize() public {
    MockConfig(address(vme)).updateSampleProxyLogicForTesting("SampleProxyForTestingPurpose2");

    vm.recordLogs();
    vm.startStateDiffRecording();

    _sample = new SampleProxyDeploy().run();

    Vm.Log[] memory logs = vm.getRecordedLogs();
    Vm.AccountAccess[] memory stateDiffs = vm.stopAndReturnStateDiff();

    ValidateWrapper _wrapper = new ValidateWrapper();
    vm.expectRevert(
      bytes(string.concat("LibInitializeGuard: Proxy ", vm.getLabel(address(_sample)), " does not initialize!".red()))
    );
    _wrapper.runValidate(logs, stateDiffs);
  }

  function testRevert_When_Does_Not_Correctly_Increment() public {
    MockConfig(address(vme)).updateSampleProxyLogicForTesting("SampleProxyForTestingPurpose3");

    vm.recordLogs();
    vm.startStateDiffRecording();

    _sample = new SampleProxyDeploy().run();

    Vm.Log[] memory logs = vm.getRecordedLogs();
    Vm.AccountAccess[] memory stateDiffs = vm.stopAndReturnStateDiff();

    ValidateWrapper _wrapper = new ValidateWrapper();
    vm.expectRevert("LibInitializeGuard: Version does not correctly increment!");
    _wrapper.runValidate(logs, stateDiffs);
  }
}
