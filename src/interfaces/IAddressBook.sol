// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { TContract } from "script/types/TContract.sol";

interface IAddressBook {
  event AddressSet(TContract indexed contractType, address indexed contractAddr);

  function setAddress(
    TContract contractType,
    address contractAddr
  ) external;

  function getAddress(
    TContract contractType
  ) external view returns (address);
}
