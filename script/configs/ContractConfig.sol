// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

enum ContractKey {
  RNSUnified,
  ProxyAdmin,
  RNSAuction,
  NameChecker,
  PublicResolver,
  RNSDomainPrice,
  RNSReverseRegistrar,
  RONRegistrarController
}

abstract contract ContractConfig {
  mapping(ContractKey contractIdx => string contractName) internal _contractNameMap;
  mapping(uint256 chainId => mapping(string name => address addr)) internal _contractAddrMap;

  constructor() payable {
    // setup contract name
    _contractNameMap[ContractKey.RNSUnified] = "RNSUnified";
    _contractNameMap[ContractKey.ProxyAdmin] = "ProxyAdmin";
    _contractNameMap[ContractKey.RNSAuction] = "RNSAuction";
    _contractNameMap[ContractKey.NameChecker] = "NameChecker";
    _contractNameMap[ContractKey.PublicResolver] = "PublicResolver";
    _contractNameMap[ContractKey.RNSDomainPrice] = "RNSDomainPrice";
    _contractNameMap[ContractKey.RNSReverseRegistrar] = "RNSReverseRegistrar";
    _contractNameMap[ContractKey.RONRegistrarController] = "RONRegistrarController";
  }

  function getContractName(ContractKey contractKey) public view returns (string memory name) {
    name = _contractNameMap[contractKey];
    require(bytes(name).length != 0, "Contract Key not found");
  }

  function getContractFileName(ContractKey contractKey) public view returns (string memory filename) {
    string memory contractName = getContractName(contractKey);
    filename = string.concat(contractName, ".sol:", contractName);
  }

  function getAddressFromCurrentNetwork(ContractKey contractKey) public view returns (address payable) {
    string memory contractName = _contractNameMap[contractKey];
    require(bytes(contractName).length != 0, "Contract Key not found");
    return getAddressByRawData(block.chainid, contractName);
  }

  function getAddressByString(string memory contractName) public view returns (address payable) {
    return getAddressByRawData(block.chainid, contractName);
  }

  function getAddressByRawData(uint256 chainId, string memory contractName) public view returns (address payable addr) {
    addr = payable(_contractAddrMap[chainId][contractName]);
    require(addr != address(0), string.concat("address not found: ", contractName));
  }
}
