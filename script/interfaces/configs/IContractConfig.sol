// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { TContract } from "../../types/TContract.sol";
import { TNetwork } from "../../types/TNetwork.sol";

interface IContractConfig {
  function setUpDefaultContracts() external;

  function setAddress(TNetwork network, TContract contractType, address contractAddr) external;

  function getAddress(TNetwork network, TContract contractType) external view returns (address payable);

  function getAllAddresses(TNetwork network) external view returns (address payable[] memory);

  function getContractTypeByRawData(TNetwork network, address contractAddr)
    external
    view
    returns (TContract contractType);

  function label(TNetwork network, address contractAddr, string memory contractName) external;

  function getContractTypeFromCurrentNetwork(address contractAddr) external view returns (TContract contractType);

  function getContractName(TContract contractType) external view returns (string memory name);

  function getContractAbsolutePath(TContract contractType) external view returns (string memory name);

  function getAddressFromCurrentNetwork(TContract contractType) external view returns (address payable);

  function getAddressByString(string calldata contractName) external view returns (address payable);

  function getAddressByRawData(TNetwork network, string calldata contractName)
    external
    view
    returns (address payable addr);

  function getAllAddressesByRawData(TNetwork network) external view returns (address payable[] memory addrs);
}
