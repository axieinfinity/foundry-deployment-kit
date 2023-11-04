// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library LibSharedAddress {
  address internal constant config = address(uint160(uint256(keccak256("config"))));
  address internal constant logger = address(uint160(uint256(keccak256("logger"))));
  address internal constant vm = address(uint160(uint256(keccak256("hevm cheat code"))));
}
