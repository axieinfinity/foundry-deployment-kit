// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { LibString } from "../../dependencies/solady-0.0.206/src/utils/LibString.sol";
import { TContract } from "../types/Types.sol";

enum DefaultContract {
  ProxyAdmin,
  Multicall2,
  Multicall3,
  WRON,
  WRONHelper,
  WETH,
  AXS,
  Scatter,
  KatanaRouter,
  KatanaFactory,
  KatanaGovernance,
  AffiliateRouter,
  PermissionedRouter,
  SCMultisig,
  USDC
}

using { key, name } for DefaultContract global;

function key(DefaultContract defaultContract) pure returns (TContract) {
  return TContract.wrap(LibString.packOne(name(defaultContract)));
}

function name(DefaultContract defaultContract) pure returns (string memory) {
  if (defaultContract == DefaultContract.ProxyAdmin) return "ProxyAdmin";
  if (defaultContract == DefaultContract.Multicall2) return "Multicall2";
  if (defaultContract == DefaultContract.Multicall3) return "Multicall3";
  if (defaultContract == DefaultContract.WRON) return "WRON";
  if (defaultContract == DefaultContract.WRONHelper) return "WRONHelper";
  if (defaultContract == DefaultContract.WETH) return "WETH";
  if (defaultContract == DefaultContract.AXS) return "AXS";
  if (defaultContract == DefaultContract.Scatter) return "Scatter";
  if (defaultContract == DefaultContract.KatanaRouter) return "KatanaRouter";
  if (defaultContract == DefaultContract.KatanaFactory) return "KatanaFactory";
  if (defaultContract == DefaultContract.KatanaGovernance) return "KatanaGovernance";
  if (defaultContract == DefaultContract.AffiliateRouter) return "AffiliateRouter";
  if (defaultContract == DefaultContract.PermissionedRouter) return "PermissionedRouter";
  if (defaultContract == DefaultContract.SCMultisig) return "SCMultisig";
  if (defaultContract == DefaultContract.USDC) return "USDC";
  revert("DefaultContract: Unknown contract");
}
