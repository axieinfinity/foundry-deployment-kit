// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";
import { LibSharedAddress } from "./LibSharedAddress.sol";

library LibProxy {
  Vm internal constant vm = Vm(LibSharedAddress.vm);
  bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
  bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  function getProxyAdmin(address payable proxy) internal view returns (address payable) {
    return payable(address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT)))));
  }

  function getProxyImplementation(address payable proxy) internal view returns (address payable) {
    return payable(address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT)))));
  }
}
