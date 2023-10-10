// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Vm, VmSafe} from "forge-std/Vm.sol";
import {LibString} from "solady/src/utils/LibString.sol";

enum ContractKey {
  ProxyAdmin,
  // RNS
  RNSRegistry,
  RNSRegistrar,
  NameWrapper,
  NameChecker,
  DummyOracle,
  RNSAuction,
  RNSDomainPrice,
  PublicResolver,
  ReverseRegistrar,
  StablePriceOracle,
  RONRegistrarController,
  // Land Staking
  LandStakingPool,
  LandStakingManager
}

enum Network {
  Local,
  RoninMainnet,
  RoninTestnet
}

library ChainId {
  uint256 public constant LOCAL = 31337;
  uint256 public constant RONIN_MAINNET = 2020;
  uint256 public constant RONIN_TESTNET = 2021;
}

contract GeneralConfig {
  using LibString for string;

  struct NetworkInfo {
    uint256 chainId;
    string privateKeyEnvLabel;
    string deploymentDir;
  }

  string public constant LOCAL_ENV_LABEL = "LOCAL_PK";
  string public constant TESTNET_ENV_LABEL = "TESTNET_PK";
  string public constant MAINNET_ENV_LABEL = "MAINNET_PK";
  string public constant DEPLOYMENT_ROOT = "deployments/";
  string public constant LOCAL_DIR = "local/";
  string public constant RONIN_TESTNET_DIR = "ronin-testnet/";
  string public constant RONIN_MAINNET_DIR = "ronin-mainnet/";

  Vm private immutable _vm;

  mapping(Network networkIdx => NetworkInfo) private _networkInfoMap;
  mapping(uint256 chainId => Network networkIdx) private _networkMap;
  mapping(ContractKey contractIdx => string contractName) private _contractNameMap;
  mapping(uint256 chainId => mapping(string name => address addr)) private _contractAddrMap;

  constructor(Vm vm) payable {
    _vm = vm;

    _setUpNetwork();
    _mapContractKeysToNames();

    _setUpHardHatDeploymentInfo();
    _setUpFoundryDeploymentInfo();

    // Manuallly setup for testnet
    setAddress(Network.RoninTestnet, ContractKey.LandStakingManager, 0x087c35EEe6b9f697f8CC0062762130E505A39003);
    setAddress(Network.RoninTestnet, ContractKey.LandStakingPool, 0x74f4aeB84F1535A777CC9B24f4C4B703F2402868);

    // Manually setup for mainnet
    setAddress(Network.RoninMainnet, ContractKey.LandStakingManager, 0x7f27E35170472E7f107d3e55C2B9bCd44aA01dD5);
    setAddress(Network.RoninMainnet, ContractKey.LandStakingPool, 0xb2A5110F163eC592F8F0D4207253D8CbC327d9fB);

    // Manually setup for localhost
    setAddress(Network.Local, ContractKey.ProxyAdmin, 0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
  }

  function _mapContractKeysToNames() internal {
    // setup contract name
    _contractNameMap[ContractKey.ProxyAdmin] = "ProxyAdmin";
    _contractNameMap[ContractKey.NameChecker] = "NameChecker";
    _contractNameMap[ContractKey.NameWrapper] = "NameWrapper";
    _contractNameMap[ContractKey.RNSAuction] = "RNSAuction";
    _contractNameMap[ContractKey.RNSRegistry] = "RNSRegistry";
    _contractNameMap[ContractKey.RNSRegistrar] = "RNSRegistrar";
    _contractNameMap[ContractKey.DummyOracle] = "MockDummyOracle";
    _contractNameMap[ContractKey.RNSDomainPrice] = "RNSDomainPrice";
    _contractNameMap[ContractKey.PublicResolver] = "PublicResolver";
    _contractNameMap[ContractKey.LandStakingPool] = "LandStakingPool";
    _contractNameMap[ContractKey.ReverseRegistrar] = "ReverseRegistrar";
    _contractNameMap[ContractKey.LandStakingManager] = "LandStakingManager";
    _contractNameMap[ContractKey.StablePriceOracle] = "MockStablePriceOracle";
    _contractNameMap[ContractKey.RONRegistrarController] = "RONRegistrarController";
  }

  function _setUpNetwork() internal {
    _networkMap[ChainId.LOCAL] = Network.Local;
    _networkInfoMap[Network.Local] = NetworkInfo(ChainId.LOCAL, LOCAL_ENV_LABEL, LOCAL_DIR);

    _networkMap[ChainId.RONIN_TESTNET] = Network.RoninTestnet;
    _networkInfoMap[Network.RoninTestnet] = NetworkInfo(ChainId.RONIN_TESTNET, TESTNET_ENV_LABEL, RONIN_TESTNET_DIR);

    _networkMap[ChainId.RONIN_MAINNET] = Network.RoninMainnet;
    _networkInfoMap[Network.RoninMainnet] = NetworkInfo(ChainId.RONIN_MAINNET, MAINNET_ENV_LABEL, RONIN_MAINNET_DIR);
  }

  function _setUpFoundryDeploymentInfo() internal {}

  function _setUpHardHatDeploymentInfo() internal {
    VmSafe.DirEntry[] memory deployments = _vm.readDir(DEPLOYMENT_ROOT);

    for (uint256 i; i < deployments.length;) {
      VmSafe.DirEntry[] memory entries = _vm.readDir(deployments[i].path);
      uint256 chainId = _vm.parseUint(_vm.readFile(string.concat(deployments[i].path, "/.chainId")));
      string[] memory s = deployments[i].path.split("/");
      string memory prefix = s[s.length - 1];

      for (uint256 j; j < entries.length;) {
        string memory path = entries[j].path;

        if (path.endsWith(".json")) {
          // filter out logic deployments
          if (!path.endsWith("Logic.json")) {
            string[] memory splitteds = path.split("/");
            string memory contractName = splitteds[splitteds.length - 1];
            string memory suffix = path.endsWith("Proxy.json") ? "Proxy.json" : ".json";
            // remove suffix
            assembly ("memory-safe") {
              mstore(contractName, sub(mload(contractName), mload(suffix)))
            }
            string memory json = _vm.readFile(path);
            address contractAddr = _vm.parseJsonAddress(json, ".address");

            _vm.label(contractAddr, string.concat(prefix, ".", contractName));
            _contractAddrMap[chainId][contractName] = contractAddr;
          }
        }

        unchecked {
          ++j;
        }
      }

      unchecked {
        ++i;
      }
    }
  }

  function setAddressForCurrentNetwork(ContractKey contractKey, address contractAddr) public {
    setAddress(getCurrentNetwork(), contractKey, contractAddr);
  }

  function setAddress(Network network, ContractKey contractKey, address contractAddr) public {
    uint256 chainId = _networkInfoMap[network].chainId;
    string memory contractName = _contractNameMap[contractKey];
    require(chainId != 0 && bytes(contractName).length != 0, "Network or Contract Key not found");

    _contractAddrMap[chainId][contractName] = contractAddr;
  }

  function getDeploymentDirectoryFromCurrentNetwork() public view returns (string memory dirPath) {
    dirPath = getDeploymentDirectory(getCurrentNetwork());
  }

  function getDeploymentDirectory(Network network) public view returns (string memory dirPath) {
    string memory dirName = _networkInfoMap[network].deploymentDir;
    require(bytes(dirName).length != 0, "Deployment dir not found");
    dirPath = string.concat(DEPLOYMENT_ROOT, dirName);
  }

  function getPrivateKeyEnvLabelFromCurrentNetwork() public view returns (string memory privatekeyEnvLabel) {
    privatekeyEnvLabel = getPrivateKeyEnvLabel(getCurrentNetwork());
  }

  function getPrivateKeyEnvLabel(Network network) public view returns (string memory privateKeyEnvLabel) {
    privateKeyEnvLabel = _networkInfoMap[network].privateKeyEnvLabel;
    require(bytes(privateKeyEnvLabel).length != 0, "ENV label not found");
  }

  function getContractName(ContractKey contractKey) public view returns (string memory name) {
    name = _contractNameMap[contractKey];
    require(bytes(name).length != 0, "Contract Key not found");
  }

  function getContractFileName(ContractKey contractKey) public view returns (string memory filename) {
    string memory contractName = getContractName(contractKey);
    filename = string.concat(contractName, ".sol:", contractName);
  }

  function getCurrentNetwork() public view returns (Network network) {
    network = _networkMap[block.chainid];
  }

  function getNetworkByChainId(uint256 chainId) public view returns (Network network) {
    network = _networkMap[chainId];
  }

  function getAddress(Network network, ContractKey contractKey) public view returns (address payable) {
    return getAddressByRawData(_networkInfoMap[network].chainId, _contractNameMap[contractKey]);
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
