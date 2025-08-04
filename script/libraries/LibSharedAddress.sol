// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

library LibSharedAddress {
  address internal constant VME = address(uint160(uint256(keccak256("vme"))));
  /// @dev Preserve constant for backwards compatibility
  address internal constant CONFIG = address(uint160(uint256(keccak256("vme"))));
  address internal constant VM = address(uint160(uint256(keccak256("hevm cheat code"))));
  address internal constant ARTIFACT_FACTORY = address(uint160(uint256(keccak256("logger"))));
}
