// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { Vm } from "../../dependencies/forge-std-1.8.2/src/Vm.sol";
import { LibSharedAddress } from "./LibSharedAddress.sol";

library LibProxy {
  Vm internal constant vm = Vm(LibSharedAddress.VM);
  bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
  bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  function getProxyAdmin(address proxy, bool nullCheck) internal view returns (address payable proxyAdmin) {
    proxyAdmin = payable(address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT)))));

    if (!nullCheck) return proxyAdmin;

    require(
      proxyAdmin != address(0x0),
      string.concat("LibProxy: Null ProxyAdmin, Provided address: ", vm.getLabel(proxy), " is not EIP1967 Proxy")
    );
  }

  function getProxyAdmin(address proxy) internal view returns (address payable proxyAdmin) {
    proxyAdmin = getProxyAdmin({ proxy: proxy, nullCheck: true });
  }

  function getProxyImplementation(address proxy, bool nullCheck) internal view returns (address payable impl) {
    impl = payable(address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT)))));

    if (!nullCheck) return impl;

    require(
      impl != address(0x0),
      string.concat("LibProxy: Null Implementation, Provided address: ", vm.getLabel(proxy), " is not EIP1967 Proxy")
    );
  }

  function getProxyImplementation(address proxy) internal view returns (address payable impl) {
    impl = getProxyImplementation({ proxy: proxy, nullCheck: true });
  }
}
