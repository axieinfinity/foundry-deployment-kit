// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { EnumerableSet } from "../../dependencies/@openzeppelin-4.9.3/contracts/utils/structs/EnumerableSet.sol";
import { JSONParserLib } from "../../dependencies/@solady-0.0.228/src/utils/JSONParserLib.sol";
import { LibString } from "../../dependencies/@solady-0.0.228/src/utils/LibString.sol";
import { Vm, VmSafe } from "../../dependencies/@forge-std-1.9.1/src/Vm.sol";
import { StdStyle } from "../../dependencies/@forge-std-1.9.1/src/StdStyle.sol";
import { console, vm, vme } from "../utils/Helpers.sol";
import { TNetwork } from "../types/TNetwork.sol";
import { TContract } from "../types/TContract.sol";

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
  using JSONParserLib for string;
  using JSONParserLib for JSONParserLib.Item;
  using LibString for string;
  using EnumerableSet for EnumerableSet.AddressSet;

  struct InitializedSlot {
    bool found;
    bytes32 slot;
    uint256 bitOffset;
    uint256 nBit;
  }

  struct Cache {
    EnumerableSet.AddressSet _logics;
    EnumerableSet.AddressSet _proxies;
    mapping(address addr => uint256) _lastInitVer;
    mapping(address addr => Vm.ChainInfo) _chainInfo;
    mapping(address proxy => InitializedSlot) _initSlot;
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

  /// @dev See: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/proxy/utils/Initializable.sol#L77
  bytes32 private constant INITIALIZABLE_STORAGE_OZV5 =
    0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

  /// @dev Custom storage slot of the `Cache` struct
  bytes32 private constant $$_CacheStorageLocation = keccak256("LibInitializeGuard.Cache.storage.slot");
  /// @dev Custom storage slot of the `StdStorage` struct
  bytes32 private constant $$_StdStorageLocation = keccak256("LibInitializeGuard.StdStorage.storage.slot");

  function validate(Vm.Log[] memory logs, Vm.AccountAccess[] memory stateDiffs) internal {
    Cache storage $ = _getCacheStorage();

    _recordUpgradesAndInitializations({ $cache: $, logs: logs });

    for (uint256 i; i < stateDiffs.length; ++i) {
      address addr = stateDiffs[i].account;

      if ($._proxies.contains(addr) && !$._initSlot[addr].found) {
        // Record the chain info and initialized slot of the `addr`.
        $._chainInfo[addr] = stateDiffs[i].chainInfo;
        $._initSlot[addr] = _getInitializedSlot($, addr);
      }

      if ($._logics.contains(addr) && stateDiffs[i].kind == VmSafe.AccountAccessKind.DelegateCall) {
        address proxy = $._logic2Proxy[addr];
        Vm.StorageAccess[] memory accs = stateDiffs[i].storageAccesses;

        for (uint256 j; j < accs.length; ++j) {
          // Skip if changes does not made changes to `initSlot` by `proxy` to `logic`
          if (!(accs[j].isWrite && accs[j].account == proxy && accs[j].slot == $._initSlot[proxy].slot)) {
            continue;
          }

          bool shouldSkip = _validateInitChanges(accs[j], $._initSlot[proxy]);
          if (shouldSkip) continue;
        }
      }
    }

    _validateLogicsVersion({ $cache: $ });
    _validateProxiesVersion({ $cache: $ });
  }

  /**
   * @dev Validate the initialized version of the logics.
   * - Check if the logic disable initialized version.
   */
  function _validateLogicsVersion(Cache storage $cache) private view {
    address[] memory logics = $cache._logics.values();
    uint256 length = logics.length;

    for (uint256 i; i < length; ++i) {
      uint256 lastInitVer = $cache._lastInitVer[logics[i]];
      address proxy = $cache._logic2Proxy[logics[i]];
      require(
        (lastInitVer == MAX_VER_V4 && $cache._initSlot[proxy].nBit == N_BIT_INIT_V4)
          || (lastInitVer == MAX_VER_V5 && $cache._initSlot[proxy].nBit == N_BIT_INIT_V5),
        string.concat("LibInitializeGuard: Logic ", vm.getLabel(logics[i]), " does not disable initialized version!")
      );
    }
  }

  /**
   * @dev Validate the initialized version of the proxies.
   * - Check if `_initialized` slot is found.
   * - Check if the last initialized version is equal to the number of `initialize` functions.
   */
  function _validateProxiesVersion(Cache storage $cache) private {
    address[] memory proxies = $cache._proxies.values();
    uint256 length = proxies.length;

    for (uint256 i; i < length; ++i) {
      address proxy = proxies[i];
      InitializedSlot memory slot = $cache._initSlot[proxy];

      require(
        slot.found,
        string.concat("LibInitializeGuard: Proxy ", vm.getLabel(proxies[i]), " does not have `_initialized` slot!")
      );

      uint256 lastInitVer = $cache._lastInitVer[proxy];

      require(
        lastInitVer != 0, string.concat("LibInitializeGuard: Proxy ", vm.getLabel(proxy), " does not initialize!")
      );

      if (
        (lastInitVer == MAX_VER_V4 && slot.nBit == N_BIT_INIT_V4)
          || (lastInitVer == MAX_VER_V5 && slot.nBit == N_BIT_INIT_V5)
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
        require(keccak256(bytes(vm.toLowercase(ret))) == keccak256("yes"), "LibInitializeGuard: User aborted!");

        continue;
      }

      uint256 initFnCount = _getInitializeFnCount($cache, proxy);
      require(
        lastInitVer == initFnCount,
        string.concat(
          "LibInitializeGuard: Invalid initialized version!",
          " Expected: ",
          vm.toString(initFnCount),
          " Got: ",
          vm.toString(lastInitVer)
        )
      );
    }
  }

  /**
   * @dev Validate the intermediate changes of the `_initialized` slot of the given `access` storage.
   *
   * @param acc The storage access of data.
   * @param slot The initialized slot of the proxy.
   * @return shouldSkip Whether to skip the validation.
   */
  function _validateInitChanges(Vm.StorageAccess memory acc, InitializedSlot memory slot)
    private
    view
    returns (bool shouldSkip)
  {
    uint256 mask = (1 << slot.nBit) - 1;

    uint256 prvVer = (uint256(acc.previousValue) >> slot.bitOffset) & mask;
    uint256 newVer = (uint256(acc.newValue) >> slot.bitOffset) & mask;

    // Skip if `_initialized` bytes location in `slot` does not change
    // Assume other data in given slot is not related to initialized version
    if (prvVer == newVer) return true;
    // Skip if the proxy disable initialized version
    if ((newVer == MAX_VER_V4 && slot.nBit == N_BIT_INIT_V4) || (newVer == MAX_VER_V5 && slot.nBit == N_BIT_INIT_V5)) {
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
    for (uint256 i; i < logs.length; ++i) {
      address emitter = logs[i].emitter;
      bytes32 eventSig = logs[i].topics[0];

      if (eventSig == InitializableOZV4.Initialized.selector) {
        $cache._lastInitVer[emitter] = abi.decode(logs[i].data, (uint8));
      }

      if (eventSig == InitializableOZV5.Initialized.selector) {
        $cache._lastInitVer[emitter] = abi.decode(logs[i].data, (uint64));
      }

      if (eventSig == IERC1967.Upgraded.selector) {
        address logic = address(uint160(uint256(logs[i].topics[1])));
        $cache._logics.add(logic);
        $cache._proxies.add(emitter);
        $cache._logic2Proxy[logic] = emitter;
      }
    }
  }

  /**
   * @dev Get the number of `initialize` functions of the given `proxy` by inspecting its storage layout using `forge inspect <contract_name> methodIdentifiers`.
   */
  function _getInitializeFnCount(Cache storage $cache, address proxy) private returns (uint256 count) {
    string[] memory inputs = new string[](4);
    inputs[0] = "forge";
    inputs[1] = "inspect";
    inputs[2] = _getContractName($cache._chainInfo[proxy].forkId, proxy);
    inputs[3] = "methodIdentifiers";

    string memory ret = vm.toLowercase(string(vm.ffi(inputs)));
    string[] memory allFns = vm.parseJsonKeys(ret, ".");
    uint256 length = allFns.length;

    for (uint256 i; i < length; ++i) {
      if (allFns[i].contains("initialize")) count++;
    }
  }

  /**
   * @dev Get `_initialized` slot of the given `proxy` by inspecting its storage layout using `forge inspect <contract_name> storage`.
   * If the slot is not found, infer it used OpenZeppelin v5 `Initializable` extension and see if the custom storage slot has value.
   */
  function _getInitializedSlot(Cache storage $cache, address proxy) private returns (InitializedSlot memory initSlot) {
    string[] memory inputs = new string[](4);
    inputs[0] = "forge";
    inputs[1] = "inspect";
    inputs[2] = _getContractName($cache._chainInfo[proxy].forkId, proxy);
    inputs[3] = "storage";

    string memory ret = string(vm.ffi(inputs));
    JSONParserLib.Item memory layout = ret.parse().at('"storage"');
    uint256 layoutSize = layout.size();

    for (uint256 i; i < layoutSize; ++i) {
      JSONParserLib.Item memory storageSlot = layout.at(i);

      if (keccak256(bytes(storageSlot.at('"label"').value().decodeString())) == keccak256("_initialized")) {
        initSlot.found = true;
        initSlot.bitOffset = storageSlot.at('"offset"').value().parseUint() * 8;
        initSlot.nBit = N_BIT_INIT_V4;
        initSlot.slot = bytes32(vm.parseUint(storageSlot.at('"slot"').value().decodeString()));

        return initSlot;
      }
    }

    if ($cache._lastInitVer[proxy] != 0) {
      // assume given proxy use `Initializable` from OpenZeppelin v5
      // ToDo(TuDo1403): switch to `forkId` if working multichain
      bytes32 slotValue = vm.load(proxy, INITIALIZABLE_STORAGE_OZV5);
      if (slotValue != 0) {
        initSlot.found = true;
        initSlot.bitOffset = 0;
        initSlot.nBit = N_BIT_INIT_V5;
        initSlot.slot = INITIALIZABLE_STORAGE_OZV5;
      }
    }
  }

  /**
   * @dev Get the contract name by the given `addr` and `forkId`.
   */
  function _getContractName(uint256 forkId, address addr) private view returns (string memory contractName) {
    TNetwork networkType = vme.getNetworkTypeByForkId(forkId);
    TContract contractType = vme.getContractTypeByRawData(networkType, addr);
    contractName = vme.getContractName(contractType);
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
