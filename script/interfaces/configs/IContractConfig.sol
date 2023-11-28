// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TContract } from "../../types/Types.sol";

interface IContractConfig {
  function getContractName(TContract contractType) external view returns (string memory name);

  function getContractAbsolutePath(TContract contractType) external view returns (string memory name);

  function getAddressFromCurrentNetwork(TContract contractType) external view returns (address payable);

  function getAddressByString(string calldata contractName) external view returns (address payable);

  function getAddressByRawData(uint256 chainId, string calldata contractName)
    external
    view
    returns (address payable addr);

  function getAllAddressesByRawData(uint256 chainId) external view returns (address payable[] memory addrs);
}
