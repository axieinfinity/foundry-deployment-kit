// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { IVme } from "../interfaces/IVme.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";
import { TNetwork } from "../types/TNetwork.sol";
import { TContract } from "../types/TContract.sol";

abstract contract BaseScriptExtended {
  bytes public constant EMPTY_ARGS = "";

  IVme public constant vme = IVme(LibSharedAddress.VME);
  // Backward compatibility
  IVme public constant CONFIG = vme;

  function network() public view virtual returns (TNetwork) {
    return vme.getCurrentNetwork();
  }

  function forkId() public view virtual returns (uint256) {
    return vme.getForkId(network());
  }

  function sender() public view virtual returns (address payable) {
    return vme.getSender();
  }

  function loadContract(TContract contractType) public view virtual returns (address payable contractAddr) {
    return vme.getAddressFromCurrentNetwork(contractType);
  }
}
