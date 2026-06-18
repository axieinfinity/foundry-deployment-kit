// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { stdJson } from "../../dependencies/forge-std-1.9.5/src/StdJson.sol";
import { StdStorage, stdStorage } from "../../dependencies/forge-std-1.9.5/src/StdStorage.sol";

import { StdStyle } from "../../dependencies/forge-std-1.9.5/src/StdStyle.sol";
import { console } from "../../dependencies/forge-std-1.9.5/src/console.sol";

import { JSONParserLib } from "../../dependencies/solady-0.0.228/src/utils/JSONParserLib.sol";
import { LibString } from "../../dependencies/solady-0.0.228/src/utils/LibString.sol";
import { LibErrorHandler } from "../libraries/LibErrorHandler.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";

import { TContract } from "../types/TContract.sol";

import { EMPTY_ARGS, vm, vme } from "./Constants.sol";

using StdStyle for string;
using LibString for address;
using LibString for string;
using stdJson for string;
using LibErrorHandler for bool;
using JSONParserLib for string;
using JSONParserLib for JSONParserLib.Item;
using stdStorage for StdStorage;

// // Set the balance of an account for any ERC20 token
// // Use the alternative signature to update `totalSupply`
// function deal(address token, address to, uint256 give) {
//   deal(token, to, give, false);
// }

// function deal(address token, address to, uint256 give, bool adjust) {
//   // get current balance
//   (, bytes memory balData) = token.staticcall(abi.encodeWithSelector(0x70a08231, to));
//   uint256 prevBal = abi.decode(balData, (uint256));

//   // update balance
//   stdstore.target(token).sig(0x70a08231).with_key(to).checked_write(give);

//   // update total supply
//   if (adjust) {
//     (, bytes memory totSupData) = token.staticcall(abi.encodeWithSelector(0x18160ddd));
//     uint256 totSup = abi.decode(totSupData, (uint256));
//     if (give < prevBal) {
//       totSup -= (prevBal - give);
//     } else {
//       totSup += (give - prevBal);
//     }
//     stdstore.target(token).sig(0x18160ddd).checked_write(totSup);
//   }
// }

function logDecodedError(
  bytes memory returnOrRevertData
) {
  if (returnOrRevertData.length != 0) {
    string[] memory commandInput = new string[](3);
    commandInput[0] = "cast";
    commandInput[1] = returnOrRevertData.length > 4 ? "4byte-decode" : "4byte";
    commandInput[2] = vm.toString(returnOrRevertData);
    bytes memory decodedError = vm.ffi(commandInput);
    console.log(StdStyle.red(string.concat("Decoded Error: ", string(decodedError))));
  }
}

function sendRawTransaction(address from, address to, uint256 gas, uint256 callValue, bytes memory callData) {
  bool success;
  bytes memory returnOrRevertData;

  prankOrBroadcast(from);

  (success, returnOrRevertData) =
    gas == 0 ? to.call{ value: callValue }(callData) : to.call{ value: callValue, gas: gas }(callData);

  if (!success) {
    if (returnOrRevertData.length != 0) logDecodedError(returnOrRevertData);
    else console.log(StdStyle.red("Evm Error!"));
  }
}

function logInnerCall(
  string memory fnName
) pure {
  console.log("> ", fnName.blue(), "...");
}

// keccak256("EIP712Domain(uint256 chainId,address verifyingContract)")
bytes32 constant SAFE_DOMAIN_SEPARATOR_TYPEHASH = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;
// keccak256("SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256
// gasPrice,address gasToken,address refundReceiver,uint256 nonce)")
bytes32 constant SAFE_TX_TYPEHASH = 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8;
// Sentinel for "no SAFE_NONCE override supplied".
uint256 constant SAFE_NONCE_UNSET = type(uint256).max;

/// @dev Canonical Safe singleton (master copy) addresses. Safe singletons are deployed deterministically, so these
/// are identical on every chain. A Safe proxy stores its singleton at storage slot 0, which lets us confirm an
/// address is a genuine Safe proxy on-chain (used as a fallback when the Safe Transaction Service is unavailable).
function _isKnownSafeSingleton(
  address singleton
) pure returns (bool) {
  return singleton == 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552 // GnosisSafe v1.3.0
    || singleton == 0x3E5c63644E683549055b9Be8653de26E0B4CD36E // GnosisSafeL2 v1.3.0
    || singleton == 0x41675C099F32341bf84BFc5382aF534df5C7461a // Safe v1.4.1
    || singleton == 0x29fcB43b46531BcA003ddC8FCB67FFE91900C762; // SafeL2 v1.4.1
}

/// @dev On-chain Safe detection: reads the proxy's singleton from storage slot 0 and checks it against the known
/// Safe singletons. Used only when the Safe Transaction Service cannot confirm the address (offline / unmapped chain).
function _isSafeProxyOnchain(
  address account
) view returns (bool) {
  address singleton = address(uint160(uint256(vm.load(account, bytes32(uint256(0))))));
  return _isKnownSafeSingleton(singleton);
}

/// @dev Safe Transaction Service base URL for `chainId`, or "" when unknown. The `SAFE_TX_SERVICE_URL` env var,
/// when set, overrides the built-in mapping (useful for self-hosted services or unlisted chains).
function _safeTxServiceBaseUrl(
  uint256 chainId
) view returns (string memory) {
  string memory fromEnv = vm.envOr("SAFE_TX_SERVICE_URL", string(""));
  if (bytes(fromEnv).length != 0) return fromEnv;
  if (chainId == 2020) return "https://safe-transaction-ronin.safe.onchainden.com"; // Ronin mainnet
  return "";
}

/// @dev Best-effort fetch of the next nonce from the Safe Transaction Service, which is queue-aware (it accounts
/// for proposed-but-not-yet-executed transactions). Returns (false, 0) when the service is unknown/unreachable or
/// the Safe is not indexed there, so the caller can fall back to the on-chain nonce.
function _tryGetSafeApiNonce(
  address safe
) returns (bool ok, uint256 nonce) {
  string memory baseUrl = _safeTxServiceBaseUrl(block.chainid);
  if (bytes(baseUrl).length == 0) return (false, 0);

  // The service requires an EIP-55 checksummed address; a lowercase address is rejected with HTTP 422.
  string memory url = string.concat(baseUrl, "/api/v1/safes/", safe.toHexStringChecksummed(), "/");
  string[] memory cmd = new string[](3);
  cmd[0] = "curl";
  cmd[1] = "-sf"; // -s: silent; -f: exit non-zero on HTTP >= 400 so `vm.ffi` reverts and we fall back
  cmd[2] = url;

  try vm.ffi(cmd) returns (bytes memory res) {
    // Body looks like {"address":"0x..","nonce":"318",...}. The leading '{' keeps `vm.ffi` from mis-decoding
    // the output as hex and guards JSONParserLib against a non-JSON 200 response.
    if (res.length == 0 || res[0] != bytes1("{")) return (false, 0);
    string memory raw = string(res).parse().at('"nonce"').value(); // e.g. "\"318\""
    if (bytes(raw).length == 0) return (false, 0);
    return (true, JSONParserLib.parseUint(JSONParserLib.decodeString(raw)));
  } catch {
    return (false, 0);
  }
}

/// @dev Resolves the Safe nonce used for hash computation, highest priority first:
///   1. `SAFE_NONCE` env var — overwrite an existing/queued nonce (e.g. to co-sign a specific pending tx)
///   2. Safe Transaction Service `nonce` (queue-aware) — passed in via `apiOk`/`apiNonce` to reuse the single API call
///   3. on-chain `Safe.nonce()`
/// `safe` is a confirmed Safe wallet, so the on-chain fallback always succeeds.
function _resolveSafeNonce(
  address safe,
  bool apiOk,
  uint256 apiNonce
) view returns (uint256 nonce, string memory source) {
  uint256 overrideNonce = vm.envOr("SAFE_NONCE", SAFE_NONCE_UNSET);
  if (overrideNonce != SAFE_NONCE_UNSET) return (overrideNonce, "overwrite (env SAFE_NONCE)");

  if (apiOk) return (apiNonce, "safe-tx-service api");

  (, bytes memory ret) = safe.staticcall(abi.encodeWithSignature("nonce()"));
  return (abi.decode(ret, (uint256)), "onchain nonce()");
}

/// @dev Pure EIP-712 hash computation for a Safe `execTransaction` with the standard defaults used by the Safe UI
/// for a simple call (operation = CALL, all gas/refund params zeroed). Assumes Safe version >= 1.3.0 (domain
/// separator includes `chainId`). Returns the domain separator, the SafeTx message hash, and the final Safe tx hash.
function computeSafeTxHashes(
  uint256 chainId,
  address safe,
  address to,
  uint256 value,
  bytes memory data,
  uint256 nonce
) pure returns (bytes32 domainHash, bytes32 messageHash, bytes32 safeTxHash) {
  domainHash = keccak256(abi.encode(SAFE_DOMAIN_SEPARATOR_TYPEHASH, chainId, safe));
  messageHash = keccak256(
    abi.encode(
      SAFE_TX_TYPEHASH,
      to,
      value,
      keccak256(data),
      uint8(0), // operation: CALL
      uint256(0), // safeTxGas
      uint256(0), // baseGas
      uint256(0), // gasPrice
      address(0), // gasToken
      address(0), // refundReceiver
      nonce
    )
  );
  safeTxHash = keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), domainHash, messageHash));
}

/// @dev Computes and logs the Safe (Gnosis Safe) EIP-712 hashes for the pending transaction so signers can
/// independently verify them (e.g. with `axieinfinity/safe-utils`, the Safe UI, or a hardware wallet) before signing.
/// Safe detection trusts the Safe Transaction Service (HTTP 200), falling back to the on-chain singleton check when
/// the service is unavailable. Silently returns when `safe` is not a Safe. See `_resolveSafeNonce` for nonce priority.
function logSafeTxHashes(address safe, address to, uint256 value, bytes memory data) {
  (bool apiOk, uint256 apiNonce) = _tryGetSafeApiNonce(safe);
  if (!apiOk && !_isSafeProxyOnchain(safe)) return; // not a Safe per the service or on-chain singleton check
  (uint256 nonce, string memory nonceSource) = _resolveSafeNonce(safe, apiOk, apiNonce);

  (bytes32 domainHash, bytes32 messageHash, bytes32 safeTxHash) =
    computeSafeTxHashes(block.chainid, safe, to, value, data, nonce);

  console.log(StdStyle.yellow("------------------------- Safe Tx Hashes -------------------------"));
  console.log(StdStyle.cyan("Safe:"), vm.getLabel(safe));
  console.log(StdStyle.cyan("Nonce:"), string.concat(vm.toString(nonce), "  (source: ", nonceSource, ")"));
  console.log(StdStyle.cyan("Domain Hash:"), vm.toString(domainHash));
  console.log(StdStyle.cyan("Message Hash:"), vm.toString(messageHash));
  console.log(StdStyle.cyan("Safe Tx Hash:"), vm.toString(safeTxHash));
  console.log("--------------------------------------------------------------------");
}

function cheatBroadcast(address from, address to, uint256 callValue, bytes memory callData) {
  string[] memory commandInputs = new string[](3);
  commandInputs[0] = "cast";
  commandInputs[1] = "4byte-decode";
  commandInputs[2] = vm.toString(callData);
  string memory decodedCallData = string(vm.ffi(commandInputs));

  console.log("\n");
  console.log("--------------------------- Call Detail ---------------------------");
  console.log(StdStyle.cyan("From:"), vm.getLabel(from));
  console.log(StdStyle.cyan("To:"), vm.getLabel(to));
  console.log(StdStyle.cyan("Value:"), vm.toString(callValue));
  console.log(
    StdStyle.cyan("Raw Calldata Data (Please double check using `cast pretty-calldata {raw_bytes}`):\n"),
    string.concat(" - ", vm.toString(callData))
  );
  console.log(StdStyle.cyan("Cast Decoded Call Data:"), decodedCallData);
  console.log("--------------------------------------------------------------------");

  logSafeTxHashes({ safe: from, to: to, value: callValue, data: callData });

  vm.prank(from);
  (bool success, bytes memory returnOrRevertData) = to.call{ value: callValue }(callData);
  success.handleRevert(bytes4(callData), returnOrRevertData);
}

function decodeData(
  bytes memory data
) returns (string memory decodedData) {
  string[] memory commandInputs = new string[](3);
  commandInputs[0] = "cast";
  commandInputs[1] = "4byte-decode";
  commandInputs[2] = vm.toString(data);
  decodedData = string(vm.ffi(commandInputs));
}

function loadContract(TContract contractType, bool shouldRevert) view returns (address payable contractAddr) {
  try vme.getAddressFromCurrentNetwork(contractType) returns (address payable res) {
    contractAddr = res;
  } catch {
    if (shouldRevert) {
      revert(string.concat("Utils: loadContract(TContract,bool): Contract not found. ", contractType.name()));
    } else {
      contractAddr = payable(address(0x0));
    }
  }
}

function prankOrBroadcast(
  address by
) {
  if (vme.isPostChecking() || vme.isPreChecking()) vm.prank(by);
  else vm.broadcast(by);
}

function deploySharedAddress(address where, bytes memory bytecode, string memory label) {
  deploySharedAddress(where, bytecode, EMPTY_ARGS, label);
}

function deploySharedAddress(address where, bytes memory bytecode, bytes memory callData, string memory label) {
  if (where.code.length == 0) {
    vm.makePersistent(where);
    vm.allowCheatcodes(where);
    if (bytes(label).length != 0) vm.label(where, label);
    deployCodeTo(EMPTY_ARGS, bytecode, callData, 0, where);
  }
}

function deployCodeTo(bytes memory creationCode, address where) {
  deployCodeTo(EMPTY_ARGS, creationCode, EMPTY_ARGS, 0, where);
}

function deployCodeTo(bytes memory creationCode, bytes memory callData, uint256 value, address where) {
  deployCodeTo(EMPTY_ARGS, creationCode, callData, value, where);
}

function deployCodeTo(
  bytes memory args,
  bytes memory creationCode,
  bytes memory callData,
  uint256 value,
  address where
) {
  vm.etch(where, abi.encodePacked(creationCode, args));
  (bool success, bytes memory runtimeBytecode) = where.call{ value: value }("");
  success.handleRevert(bytes4(callData), runtimeBytecode);

  vm.etch(where, runtimeBytecode);

  bytes memory revertOrRevertData;
  if (callData.length != 0) {
    (success, revertOrRevertData) = where.call(callData);
    success.handleRevert(bytes4(callData), revertOrRevertData);
  }
}

function deployCode(string memory what, bytes memory args) returns (address addr) {
  bytes memory bytecode = abi.encodePacked(vm.getCode(what), args);

  assembly ("memory-safe") {
    addr := create(0, add(bytecode, 0x20), mload(bytecode))
  }

  require(addr != address(0), "Utils: deployCode(string,bytes): Deployment failed.");
}

function deployCode(string memory what, uint256 val) returns (address addr) {
  bytes memory bytecode = vm.getCode(what);

  assembly ("memory-safe") {
    addr := create(val, add(bytecode, 0x20), mload(bytecode))
  }

  require(addr != address(0), "Utils: deployCode(string,uint256): Deployment failed.");
}
