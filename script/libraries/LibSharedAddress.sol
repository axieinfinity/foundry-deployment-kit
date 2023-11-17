// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library LibSharedAddress {
  address internal constant CONFIG = address(uint160(uint256(keccak256("config"))));
  address internal constant VM = address(uint160(uint256(keccak256("hevm cheat code"))));
  address internal constant ARTIFACT_FACTORY = address(uint160(uint256(keccak256("logger"))));
}
