// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { Vm } from "../../dependencies/@forge-std-1.9.1/src/Vm.sol";
import { EnumerableSet } from "../../dependencies/@openzeppelin-4.9.3/contracts/utils/structs/EnumerableSet.sol";
import { console, vm, vme } from "../utils/Helpers.sol";

interface IInitializableV4 {
  event Initialized(uint8 version);
}

interface IInitializableV5 {
  event Initialized(uint64 version);
}

interface IERC1967 {
  event Upgraded(address indexed implementation);
}

library LibInitializeGuard {
  using EnumerableSet for EnumerableSet.AddressSet;

  struct Cache {
    EnumerableSet.AddressSet _proxies;
    mapping(address proxy => address logic) _proxy2Logic;
    mapping(address addr => uint256) _initializedVersion;
  }

  bytes32 internal constant $$_CacheStoragePosition = keccak256("LibInitializeGuard.cache.storage.slot");

  function start() internal {
    bool entered;
    try vme.getUserDefinedConfig("LibInitializeGuard") returns (bytes memory ret) {
      entered = abi.decode(ret, (bool));
    } catch { }
    require(!entered, "LibInitializeGuard: already entered");
    vme.setUserDefinedConfig("LibInitializeGuard", abi.encode(true));

    vm.recordLogs();
    vm.startStateDiffRecording();
  }

  function end() internal {
    bool entered;
    try vme.getUserDefinedConfig("LibInitializeGuard") returns (bytes memory ret) {
      entered = abi.decode(ret, (bool));
    } catch { }
    require(entered, "LibInitializeGuard: not entered");
    vme.setUserDefinedConfig("LibInitializeGuard", abi.encode(false));

    Vm.Log[] memory logs = vm.getRecordedLogs();
    Vm.AccountAccess[] memory diffs = vm.stopAndReturnStateDiff();

    Cache storage $cache = _getCache();

    for (uint256 i; i < logs.length; ++i) {
      if (logs[i].topics[0] == IInitializableV4.Initialized.selector) {
        uint8 version = abi.decode(logs[i].data, (uint8));
        $cache._initializedVersion[logs[i].emitter] = version;
      } else if (logs[i].topics[0] == IInitializableV5.Initialized.selector) {
        uint64 version = abi.decode(logs[i].data, (uint64));
        $cache._initializedVersion[logs[i].emitter] = version;
      } else if (logs[i].topics[0] == IERC1967.Upgraded.selector) {
        address impl = address(uint160(uint256(logs[i].topics[1])));
        $cache._proxy2Logic[logs[i].emitter] = impl;
        $cache._proxies.add(logs[i].emitter);
      }
    }

    for (uint256 i; i < diffs.length; ++i) {
      if ($cache._proxies.contains(diffs[i].account)) {
        Vm.StorageAccess[] memory storageAccesses = diffs[i].storageAccesses;
        uint256 version = $cache._initializedVersion[diffs[i].account];

        for (uint256 j; j < storageAccesses.length; ++j) {
          if (!storageAccesses[j].reverted && storageAccesses[j].isWrite && storageAccesses[j].newValue == version) { }
        }
      }
    }
  }

  function _getCache() internal pure returns (Cache storage $) {
    bytes32 slot = $$_CacheStoragePosition;
    assembly ("memory-safe") {
      $.slot := slot
    }
  }
}
