// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { StdStyle } from "../../dependencies/forge-std-1.9.5/src/StdStyle.sol";
import { Vm, VmSafe } from "../../dependencies/forge-std-1.9.5/src/Vm.sol";
import { Math } from "../../dependencies/openzeppelin-v5-5.1.0/contracts/utils/math/Math.sol";
import { EnumerableSet } from "../../dependencies/openzeppelin-v5-5.1.0/contracts/utils/structs/EnumerableSet.sol";
import { JSONParserLib } from "../../dependencies/solady-0.0.228/src/utils/JSONParserLib.sol";
import { LibString } from "../../dependencies/solady-0.0.228/src/utils/LibString.sol";

import { TContract } from "../types/TContract.sol";
import { TNetwork } from "../types/TNetwork.sol";
import { console, vm, vme } from "../utils/Helpers.sol";

interface InitializableOZV4 {
  event Initialized(uint8);
}

interface InitializableOZV5 {
  event Initialized(uint64);
}

interface IERC1967 {
  event Upgraded(address indexed);
}

/**
 * @dev Library to guard the initialization of the proxies and logics.
 * - Proxy:
 *   + The proxy MUST have `_initialized` slot.
 *   + `_initialized` value MUST increment by 1 after each `initialize` function call.
 *   + The last initialized version MUST equal to the number of `initialize` functions.
 * - Logic:
 *   + The logic MUST disable the initialized version.
 */
library LibInitializeGuard {
  using StdStyle for *;
  using LibString for string;
  using JSONParserLib for string;
  using JSONParserLib for JSONParserLib.Item;
  using EnumerableSet for EnumerableSet.AddressSet;

  struct InitLocation {
    bytes32 slot;
    uint256 bitOffset;
    uint256 nBit;
  }

  struct Cache {
    EnumerableSet.AddressSet _logics;
    EnumerableSet.AddressSet _proxies;
    mapping(address addr => uint256) _lastInitVer;
    mapping(address addr => Vm.ChainInfo) _chainInfo;
    mapping(address proxy => InitLocation) _initSlot;
    mapping(address logic => address proxy) _logic2Proxy;
  }

  /// @dev Number of bits used to store initialized version in `_initialized` slot of OpenZeppelin v4
  uint256 private constant N_BIT_INIT_V4 = 8;
  /// @dev Maximum value of initialized version in `_initialized` slot of OpenZeppelin v4
  uint256 private constant MAX_VER_V4 = type(uint8).max;
  /// @dev Number of bits used to store initialized version in `_initialized` slot of OpenZeppelin v5
  uint256 private constant N_BIT_INIT_V5 = 64;
  /// @dev Maximum value of initialized version in `_initialized` slot of OpenZeppelin v5
  uint256 private constant MAX_VER_V5 = type(uint64).max;

  /// @dev See:
  /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/proxy/utils/Initializable.sol#L77
  bytes32 private constant INITIALIZABLE_STORAGE_OZV5 =
    0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

  /// @dev Custom storage slot of the `Cache` struct
  bytes32 private constant $$_CacheStorageLocation = keccak256("LibInitializeGuard.Cache.storage.slot");
  /// @dev Custom storage slot of the `StdStorage` struct
  bytes32 private constant $$_StdStorageLocation = keccak256("LibInitializeGuard.StdStorage.storage.slot");

  /**
   * @dev Validate the initialization of the proxies and logics.
   *
   * Requirements:
   * - Must record `logs` via `vm.recordLogs()` before calling this function.
   * - Must record `stateDiffs` via `vm.startStateDiffRecording()` before calling this function.
   *
   * @param logs The logs of the transactions.
   * @param stateDiffs The state diffs of the transactions.
   */
  function validate(Vm.Log[] memory logs, Vm.AccountAccess[] memory stateDiffs) internal {
    vm.pauseGasMetering();
    Cache storage $ = _getCacheStorage();

    _recordUpgradesAndInitializations({ $cache: $, logs: logs });

    for (uint256 i; i < stateDiffs.length; ++i) {
      address addr = stateDiffs[i].account;

      if ($._proxies.contains(addr) && $._initSlot[addr].nBit == 0) {
        // Record the chain info and initialized slot of the `addr`.
        $._chainInfo[addr] = stateDiffs[i].chainInfo;
        $._initSlot[addr] = _getInitializedSlot($, addr);
      }

      if ($._logics.contains(addr) && stateDiffs[i].kind == VmSafe.AccountAccessKind.DelegateCall) {
        address proxy = $._logic2Proxy[addr];
        InitLocation memory initLoc = $._initSlot[proxy];
        Vm.StorageAccess[] memory accs = stateDiffs[i].storageAccesses;

        for (uint256 j; j < accs.length; ++j) {
          // Skip if changes does not made changes to `initSlot` by `proxy` to `logic`
          if (!(accs[j].isWrite && accs[j].account == proxy && accs[j].slot == initLoc.slot)) continue;

          bool shouldSkip = _validateInitChanges(accs[j], initLoc);
          if (shouldSkip) continue;
        }
      }
    }

    _validateLogicsVersion({ $cache: $ });
    _validateProxiesVersion({ $cache: $ });
    vm.resumeTracing();
  }

  /**
   * @dev Validate the initialized version of the logics.
   * - Check if the logic disable initialized version.
   */
  function _validateLogicsVersion(
    Cache storage $cache
  ) private view {
    address[] memory logics = $cache._logics.values();
    uint256 length = logics.length;

    for (uint256 i; i < length; ++i) {
      uint256 lastInitVer = $cache._lastInitVer[logics[i]];

      require(
        lastInitVer == MAX_VER_V4 || lastInitVer == MAX_VER_V5,
        string.concat("LibInitializeGuard: Logic ", vm.getLabel(logics[i]), " did not disable initialized version!")
      );
    }
  }

  /**
   * @dev Validate the initialized version of the proxies.
   * - Check if `_initialized` slot is found.
   * - Check if the last initialized version is equal to the number of `initialize` functions.
   */
  function _validateProxiesVersion(
    Cache storage $cache
  ) private {
    address[] memory proxies = $cache._proxies.values();
    uint256 length = proxies.length;

    for (uint256 i; i < length; ++i) {
      address proxy = proxies[i];
      InitLocation memory initLoc = $cache._initSlot[proxy];

      require(
        initLoc.nBit != 0,
        string.concat("LibInitializeGuard: Proxy ", vm.getLabel(proxies[i]), " does not have `_initialized` slot!")
      );

      uint256 lastInitVer = $cache._lastInitVer[proxy];
      // ToDo(TuDo1403): handle multi-chain
      uint256 actualInitVer = _getVersionFromSlotValue(vm.load(proxy, initLoc.slot), initLoc.bitOffset, initLoc.nBit);

      require(
        lastInitVer != 0 || actualInitVer != 0,
        string.concat("LibInitializeGuard: Proxy ", vm.getLabel(proxy), " does not initialize!".red())
      );
      // Allow upgrade without initialization
      require(actualInitVer >= lastInitVer, "LibInitializeGuard: `lastInitVer` > `actualInitVer`!");

      actualInitVer = Math.max(lastInitVer, actualInitVer);

      if (
        (actualInitVer == MAX_VER_V4 && initLoc.nBit == N_BIT_INIT_V4)
          || (actualInitVer == MAX_VER_V5 && initLoc.nBit == N_BIT_INIT_V5)
      ) {
        string memory ret = vm.prompt(
          string.concat(
            "[WARNING] ".yellow(),
            vm.getLabel(proxy),
            " disabled initialized version.".yellow(),
            " Is it intentional?\n".yellow(),
            "Press ",
            "yes ".blue(),
            "to continue..."
          )
        );
        require(
          keccak256(bytes(vm.toLowercase(ret))) == keccak256("yes"),
          "LibInitializeGuard: Aborted due to unintended disable initialization!"
        );

        continue;
      }

      uint256 initFnCount = _getInitializeFnCount($cache, proxy);
      require(
        actualInitVer == initFnCount,
        string.concat(
          "LibInitializeGuard: Invalid initialized version!",
          " Expected: ",
          vm.toString(initFnCount),
          " Got: ",
          vm.toString(actualInitVer)
        )
      );
    }
  }

  /**
   * @dev Validate the intermediate changes of the `_initialized` slot of the given `access` storage.
   *
   * @param acc The storage access of data.
   * @param initLoc The initialized location data of the proxy.
   * @return shouldSkip Whether to skip the validation.
   */
  function _validateInitChanges(
    Vm.StorageAccess memory acc,
    InitLocation memory initLoc
  ) private view returns (bool shouldSkip) {
    uint256 prvVer = _getVersionFromSlotValue(acc.previousValue, initLoc.bitOffset, initLoc.nBit);
    uint256 newVer = _getVersionFromSlotValue(acc.newValue, initLoc.bitOffset, initLoc.nBit);

    // Skip if `_initialized` bytes location in `slot` does not change
    // Assume other data in given slot is not related to initialized version
    if (prvVer == newVer) return true;

    uint256 initBit = initLoc.nBit;
    // Skip if the proxy disable initialized version
    if ((newVer == MAX_VER_V4 && initBit == N_BIT_INIT_V4) || (newVer == MAX_VER_V5 && initBit == N_BIT_INIT_V5)) {
      console.log("[INIT] %s: Disabled initialized version", vm.getLabel(acc.account));
      return true;
    }

    console.log(unicode"[INIT] %s: v%d → v%d", vm.getLabel(acc.account), prvVer, newVer);

    require(newVer == prvVer + 1, "LibInitializeGuard: Version does not correctly increment!");
  }

  /**
   * @dev Record the upgrades and initializations of proxies and logics.
   */
  function _recordUpgradesAndInitializations(Cache storage $cache, Vm.Log[] memory logs) private {
    uint256 length = logs.length;

    for (uint256 i; i < length; ++i) {
      address emitter = logs[i].emitter;
      bytes32 eventTopic = logs[i].topics[0];

      if (eventTopic == InitializableOZV4.Initialized.selector) {
        $cache._lastInitVer[emitter] = abi.decode(logs[i].data, (uint8));
      }

      if (eventTopic == InitializableOZV5.Initialized.selector) {
        $cache._lastInitVer[emitter] = abi.decode(logs[i].data, (uint64));
      }

      if (eventTopic == IERC1967.Upgraded.selector) {
        address logic = address(uint160(uint256(logs[i].topics[1])));
        $cache._logics.add(logic);
        $cache._proxies.add(emitter);
        $cache._logic2Proxy[logic] = emitter;
      }
    }
  }

  /**
   * @dev Get the version from the given `value` at the `bitOffset` and `nBit`.
   */
  function _getVersionFromSlotValue(bytes32 value, uint256 bitOffset, uint256 nBit) private pure returns (uint256) {
    uint256 mask = (1 << nBit) - 1;
    return (uint256(value) >> bitOffset) & mask;
  }

  /**
   * @dev Get the number of `initialize` functions of the given `proxy` by inspecting its storage layout using `forge
   * inspect <contract_name> methodIdentifiers --json`.
   */
  function _getInitializeFnCount(Cache storage $cache, address proxy) private returns (uint256 count) {
    string[] memory inputs = new string[](5);
    inputs[0] = "forge";
    inputs[1] = "inspect";
    inputs[2] = _getContractAbsolutePath($cache._chainInfo[proxy].forkId, proxy);
    inputs[3] = "methodIdentifiers";
		inputs[4] = "--json";

    string memory ret = vm.toLowercase(string(vm.ffi(inputs)));
    string[] memory allFns = vm.parseJsonKeys(ret, ".");
    uint256 length = allFns.length;

    for (uint256 i; i < length; ++i) {
      if (allFns[i].startsWith("initialize")) count++;
    }
  }

  /**
   * @dev Get `_initialized` slot of the given `proxy` by inspecting its storage layout using `forge inspect
   * <contract_name> storage`.
   * If the slot is not found, infer it used OpenZeppelin v5 `Initializable` extension.
   */
  function _getInitializedSlot(Cache storage $cache, address proxy) private returns (InitLocation memory initSlot) {
    // Assume the proxy uses OpenZeppelin v5 `Initializable` extension
    initSlot.nBit = N_BIT_INIT_V5;
    initSlot.slot = INITIALIZABLE_STORAGE_OZV5;

    string[] memory inputs = new string[](5);
    inputs[0] = "forge";
    inputs[1] = "inspect";
    inputs[2] = _getContractAbsolutePath($cache._chainInfo[proxy].forkId, proxy);
    inputs[3] = "storage";
    inputs[4] = "--json";

    string memory ret = string(vm.ffi(inputs));
    JSONParserLib.Item memory layout = ret.parse().at('"storage"');
    uint256 layoutSize = layout.size();

    for (uint256 i; i < layoutSize; ++i) {
      JSONParserLib.Item memory storageSlot = layout.at(i);

      if (keccak256(bytes(storageSlot.at('"label"').value().decodeString())) == keccak256("_initialized")) {
        initSlot.bitOffset = storageSlot.at('"offset"').value().parseUint() * 8;
        initSlot.nBit = N_BIT_INIT_V4;
        initSlot.slot = bytes32(vm.parseUint(storageSlot.at('"slot"').value().decodeString()));

        return initSlot;
      }
    }
  }

  /**
   * @dev Get the contract absolute path by the given `addr` and `forkId`.
   */
  function _getContractAbsolutePath(uint256 forkId, address addr) private view returns (string memory contractName) {
    TNetwork networkType = vme.getNetworkTypeByForkId(forkId);
    TContract contractType = vme.getContractTypeByRawData(networkType, addr);
    string memory contractNameMap = _getContractNameFromAbsolutePath(vme.getContractAbsolutePath(contractType));
    contractName = contractNameMap;
  }

  function _getContractNameFromAbsolutePath(
    string memory path
  ) internal pure returns (string memory contractName) {
    uint256 length = bytes(path).length;
    // Remove ".sol"
    contractName = path;
    if (path.endsWith(".sol")) contractName = path.slice(0, length - 4);
    string[] memory parts = contractName.split(":");
    if (parts.length != 0) contractName = parts[parts.length - 1];
    parts = contractName.split("/");
    if (parts.length != 0) contractName = parts[parts.length - 1];
  }

  /**
   * @dev Get the storage slot of the `Cache` struct.
   */
  function _getCacheStorage() private pure returns (Cache storage $) {
    bytes32 slot = $$_CacheStorageLocation;

    assembly ("memory-safe") {
      $.slot := slot
    }
  }
}
