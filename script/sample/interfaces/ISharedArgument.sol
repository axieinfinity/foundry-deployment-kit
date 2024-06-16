// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { IGeneralConfig } from "@fdk/interfaces/IGeneralConfig.sol";

interface ISharedArgument is IGeneralConfig {
  struct SharedParameter {
    string message;
    string proxyMessage;
    address mFactory;
    address testnetFactory;
    bytes32 mPairCodeHash;
    bytes32 testnetPairCodeHash;
    address mWRON;
    address mSLP;
    address mAXS;
    address mWETH;
    address mBERRY;
  }

  function sharedArguments() external view returns (SharedParameter memory param);
}
