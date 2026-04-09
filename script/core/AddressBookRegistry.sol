// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { IAddressBook } from "src/interfaces/IAddressBook.sol";
import { TContract } from "script/types/TContract.sol";

contract AddressBookRegistry is IAddressBook {
  address public owner;

  mapping(TContract contractType => address contractAddr) private _contractAddrMap;

  modifier onlyOwner() {
    if (owner != address(0)) {
      require(msg.sender == owner, "AddressBookRegistry: Unauthorized");
    }
    _;
  }

  constructor(
    address owner_
  ) {
    owner = owner_ == address(0) ? msg.sender : owner_;
  }

  function setAddress(
    TContract contractType,
    address contractAddr
  ) external override onlyOwner {
    require(contractAddr != address(0), "AddressBookRegistry: Zero address");
    _contractAddrMap[contractType] = contractAddr;
    emit AddressSet(contractType, contractAddr);
  }

  function getAddress(
    TContract contractType
  ) external view override returns (address) {
    address addr = _contractAddrMap[contractType];
    require(addr != address(0), "AddressBookRegistry: Address not found");
    return addr;
  }

  function transferOwnership(
    address newOwner
  ) external onlyOwner {
    require(newOwner != address(0), "AddressBookRegistry: Zero owner");
    owner = newOwner;
  }
}
