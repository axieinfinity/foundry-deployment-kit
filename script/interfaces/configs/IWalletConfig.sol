// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IWalletConfig {
  function getSender() external view returns (address payable sender);
}
