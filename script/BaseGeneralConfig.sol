// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { StdStyle } from "../dependencies/forge-std-1.9.5/src/StdStyle.sol";
import { Vm, VmSafe } from "../dependencies/forge-std-1.9.5/src/Vm.sol";
import { console } from "../dependencies/forge-std-1.9.5/src/console.sol";

import { ContractConfig, EnumerableSet, TContract } from "./configs/ContractConfig.sol";
import { MigrationConfig } from "./configs/MigrationConfig.sol";
import { NetworkConfig, TNetwork } from "./configs/NetworkConfig.sol";
import { RuntimeConfig } from "./configs/RuntimeConfig.sol";
import { UserDefinedConfig } from "./configs/UserDefinedConfig.sol";
import { WalletConfig } from "./configs/WalletConfig.sol";

import { ISharedParameter } from "./interfaces/configs/ISharedParameter.sol";

import { LibSharedAddress } from "./libraries/LibSharedAddress.sol";
import { DefaultContract } from "./utils/DefaultContract.sol";
import { DefaultNetwork } from "./utils/DefaultNetwork.sol";

contract BaseGeneralConfig is
  RuntimeConfig,
  WalletConfig,
  ContractConfig,
  NetworkConfig,
  MigrationConfig,
  UserDefinedConfig
{
  using StdStyle for *;
  using EnumerableSet for EnumerableSet.AddressSet;

  fallback() external {
    if (msg.sig == ISharedParameter.sharedArguments.selector) {
      bytes memory returnData = getRawSharedArguments();
      assembly ("memory-safe") {
        return(add(returnData, 0x20), mload(returnData))
      }
    } else {
      revert("GeneralConfig: Unknown instruction, please rename interface to sharedArguments()");
    }
  }

  constructor(
    string memory absolutePath,
    string memory deploymentRoot
  ) NetworkConfig(deploymentRoot) ContractConfig(absolutePath, deploymentRoot) {
    console.log("GeneralConfig: ", absolutePath);
    _setUpDefaultNetworks();
    _setUpDefaultContracts();
    _setUpDefaultSender();
    _storeDeploymentData(deploymentRoot);
  }

  function setUpDefaultContracts() public {
    _setUpDefaultContracts();
  }

  function _setUpNetworks() internal virtual { }

  function _setUpContracts() internal virtual { }

  function _setUpSender() internal virtual { }

  function _setUpDefaultNetworks() private {
    setNetworkInfo(DefaultNetwork.LocalHost.data());
    setNetworkInfo(DefaultNetwork.RoninTestnet.data());
    setNetworkInfo(DefaultNetwork.RoninMainnet.data());

    _setUpNetworks();
  }

  function _setUpDefaultContracts() private {
    _contractNameMap[DefaultContract.ProxyAdmin.key()] = DefaultContract.ProxyAdmin.name();
    _contractNameMap[DefaultContract.Multicall3.key()] = DefaultContract.Multicall3.name();

    // ------------------------- Localhost -------------------------
    TNetwork localhost = DefaultNetwork.LocalHost.key();
    setAddress(localhost, DefaultContract.ProxyAdmin.key(), address(0xdead));

    // ------------------------- Ronin Testnet -------------------------
    TNetwork roninTestnet = DefaultNetwork.RoninTestnet.key();

    // Double check source: https://saigon-app.roninchain.com/address/0x505d91E8fd2091794b45b27f86C045529fa92CD7
    setAddress(roninTestnet, DefaultContract.ProxyAdmin.key(), 0x505d91E8fd2091794b45b27f86C045529fa92CD7);

    // Double check source: https://saigon-app.roninchain.com/address/0xcA11bde05977b3631167028862bE2a173976CA11
    setAddress(roninTestnet, DefaultContract.Multicall3.key(), 0xcA11bde05977b3631167028862bE2a173976CA11);

    // Double check source: https://saigon-app.roninchain.com/address/0xA959726154953bAe111746E265E6d754F48570E6
    setAddress(roninTestnet, DefaultContract.WRON.key(), 0xA959726154953bAe111746E265E6d754F48570E6);

    // Double check source: https://saigon-app.roninchain.com/address/0x2D3Aa3503B4EB3EEea370e2e089E3DEe43D5091C
    setAddress(roninTestnet, DefaultContract.WRONHelper.key(), 0x2D3Aa3503B4EB3EEea370e2e089E3DEe43D5091C);

    // Double check source: https://saigon-app.roninchain.com/address/0x29C6F8349A028E1bdfC68BFa08BDee7bC5D47E16
    setAddress(roninTestnet, DefaultContract.WETH.key(), 0x29C6F8349A028E1bdfC68BFa08BDee7bC5D47E16);

    // Double check source: https://saigon-app.roninchain.com/address/0x3C4e17b9056272Ce1b49F6900d8cFD6171a1869d
    setAddress(roninTestnet, DefaultContract.AXS.key(), 0x3C4e17b9056272Ce1b49F6900d8cFD6171a1869d);

    // Double check source: https://saigon-app.roninchain.com/address/0xFc4090C0A3c07155484Da061B9d9cB8650e6A8cC
    setAddress(roninTestnet, DefaultContract.Scatter.key(), 0xFc4090C0A3c07155484Da061B9d9cB8650e6A8cC);

    // Double check source: https://saigon-app.roninchain.com/address/0xDa44546C0715ae78D454fE8B84f0235081584Fe0
    setAddress(roninTestnet, DefaultContract.KatanaRouter.key(), 0xDa44546C0715ae78D454fE8B84f0235081584Fe0);

    // Double check source: https://saigon-app.roninchain.com/address/0x86587380C4c815Ba0066c90aDB2B45CC9C15E72c
    setAddress(roninTestnet, DefaultContract.KatanaFactory.key(), 0x86587380C4c815Ba0066c90aDB2B45CC9C15E72c);

    // Double check source: https://saigon-app.roninchain.com/address/0x247F12836A421CDC5e22B93Bf5A9AAa0f521f986
    setAddress(roninTestnet, DefaultContract.KatanaGovernance.key(), 0x247F12836A421CDC5e22B93Bf5A9AAa0f521f986);

    // Double check source: https://saigon-app.roninchain.com/address/0x4a913d50E618Ee9F61FfA288D8f8040D489d2360
    setAddress(roninTestnet, DefaultContract.AffiliateRouter.key(), 0x4a913d50E618Ee9F61FfA288D8f8040D489d2360);

    // Double check source: https://saigon-app.roninchain.com/address/0x3BD36748D17e322cFB63417B059Bcc1059012D83
    setAddress(roninTestnet, DefaultContract.PermissionedRouter.key(), 0x3BD36748D17e322cFB63417B059Bcc1059012D83);

    // Double check source: https://saigon-app.roninchain.com/address/0x067fbff8990c58ab90bae3c97241c5d736053f77
    setAddress(roninTestnet, DefaultContract.USDC.key(), 0x067fbff8990c58ab90bae3c97241c5d736053f77);

    // Double check source: https://saigon-app.roninchain.com/address/0xcaCA1c072D26E46686d932686015207FbE08FdB8
    setAddress(roninTestnet, DefaultContract.Axie.key(), 0xcaCA1c072D26E46686d932686015207FbE08FdB8);

    // Double check source: https://saigon-app.roninchain.com/address/0xA2aa501b19aff244D90cc15a4Cf739D2725B5729
    setAddress(roninTestnet, DefaultContract.Pyth.key(), 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729);

    // Double check source: https://saigon-app.roninchain.com/address/0x2E889348bD37f192063Bfec8Ff39bD3635949e20
    setAddress(roninTestnet, DefaultContract.ERC721BatchTransfer.key(), 0x2E889348bD37f192063Bfec8Ff39bD3635949e20);

    // Double check source: https://saigon-app.roninchain.com/address/0x53Ea388CB72081A3a397114a43741e7987815896
    setAddress(roninTestnet, DefaultContract.RoninGovernanceAdmin.key(), 0x53Ea388CB72081A3a397114a43741e7987815896);

    // Double check source: https://saigon-app.roninchain.com/address/0x54B3AC74a90E64E8dDE60671b6fE8F8DDf18eC9d
    setAddress(roninTestnet, DefaultContract.RoninValidatorSet.key(), 0x54B3AC74a90E64E8dDE60671b6fE8F8DDf18eC9d);

    // Double check source: https://saigon-app.roninchain.com/address/0x3b67c8D22a91572a6AB18acC9F70787Af04A4043
    setAddress(roninTestnet, DefaultContract.Profile.key(), 0x3b67c8D22a91572a6AB18acC9F70787Af04A4043);

    // Double check source: https://saigon-app.roninchain.com/address/0xA60c1e07fa030E4B49Eb54950ADb298Ab94dD312
    setAddress(roninTestnet, DefaultContract.RoninVRFCoordinator.key(), 0xA60c1e07fa030E4B49Eb54950ADb298Ab94dD312);

    // ------------------------- Ronin Mainnet -------------------------
    TNetwork roninMainnet = DefaultNetwork.RoninMainnet.key();
    // Double check source: https://app.roninchain.com/address/0xA3e7d085E65CB0B916f6717da876b7bE5cC92f03
    setAddress(roninMainnet, DefaultContract.ProxyAdmin.key(), 0xA3e7d085E65CB0B916f6717da876b7bE5cC92f03);

    // Double check source: https://app.roninchain.com/address/0xC76d0d0D3Aa608190f78db02Bf2f5AeF374fC0b9
    setAddress(roninMainnet, DefaultContract.Multicall2.key(), 0xC76d0d0D3Aa608190f78db02Bf2f5AeF374fC0b9);

    // Double check source: https://app.roninchain.com/address/0xcA11bde05977b3631167028862bE2a173976CA11
    setAddress(roninMainnet, DefaultContract.Multicall3.key(), 0xcA11bde05977b3631167028862bE2a173976CA11);

    // Double check source: https://app.roninchain.com/address/0xe514d9DEB7966c8BE0ca922de8a064264eA6bcd4
    setAddress(roninMainnet, DefaultContract.WRON.key(), 0xe514d9DEB7966c8BE0ca922de8a064264eA6bcd4);

    // Double check source: https://app.roninchain.com/address/0xCAF3E62b27a3dF0766721d1959d22b066E1a57F1
    setAddress(roninMainnet, DefaultContract.WRONHelper.key(), 0xCAF3E62b27a3dF0766721d1959d22b066E1a57F1);

    // Double check source: https://app.roninchain.com/address/0xc99a6A985eD2Cac1ef41640596C5A5f9F4E19Ef5
    setAddress(roninMainnet, DefaultContract.WETH.key(), 0xc99a6A985eD2Cac1ef41640596C5A5f9F4E19Ef5);

    // Double check source: https://app.roninchain.com/address/0x97a9107C1793BC407d6F527b77e7fff4D812bece
    setAddress(roninMainnet, DefaultContract.AXS.key(), 0x97a9107C1793BC407d6F527b77e7fff4D812bece);

    // Double check source: https://app.roninchain.com/address/0x5d518933351a0bC14B24B329b33b813565608769
    setAddress(roninMainnet, DefaultContract.Scatter.key(), 0x5d518933351a0bC14B24B329b33b813565608769);

    // Double check source: https://app.roninchain.com/address/0x7D0556D55ca1a92708681e2e231733EBd922597D
    setAddress(roninMainnet, DefaultContract.KatanaRouter.key(), 0x7D0556D55ca1a92708681e2e231733EBd922597D);

    // Double check source: https://app.roninchain.com/address/0xB255D6A720BB7c39fee173cE22113397119cB930
    setAddress(roninMainnet, DefaultContract.KatanaFactory.key(), 0xB255D6A720BB7c39fee173cE22113397119cB930);

    // Double check source: https://app.roninchain.com/address/0x2C1726346d83cBF848bD3C2B208ec70d32a9E44a
    setAddress(roninMainnet, DefaultContract.KatanaGovernance.key(), 0x2C1726346d83cBF848bD3C2B208ec70d32a9E44a);

    // Double check source: https://app.roninchain.com/address/0x77F96cF7b98B963fB8A9b84787806D396d953b2b
    setAddress(roninMainnet, DefaultContract.AffiliateRouter.key(), 0x77F96cF7b98B963fB8A9b84787806D396d953b2b);

    // Double check source: https://app.roninchain.com/address/0xC05AFC8c9353c1dd5f872EcCFaCD60fd5A2a9aC7
    setAddress(roninMainnet, DefaultContract.PermissionedRouter.key(), 0xC05AFC8c9353c1dd5f872EcCFaCD60fd5A2a9aC7);

    // Double check source: https://app.roninchain.com/address/0x9D05D1F5b0424F8fDE534BC196FFB6Dd211D902a
    setAddress(roninMainnet, DefaultContract.SCMultisig.key(), 0x9D05D1F5b0424F8fDE534BC196FFB6Dd211D902a);

    // Double check source: https://app.roninchain.com/address/0x0B7007c13325C48911F73A2daD5FA5dCBf808aDc
    setAddress(roninMainnet, DefaultContract.USDC.key(), 0x0B7007c13325C48911F73A2daD5FA5dCBf808aDc);

    // Double check source: https://app.roninchain.com/address/0x32950db2a7164aE833121501C797D79E7B79d74C
    setAddress(roninMainnet, DefaultContract.Axie.key(), 0x32950db2a7164aE833121501C797D79E7B79d74C);

    // Double check source: https://app.roninchain.com/address/0x2880aB155794e7179c9eE2e38200202908C17B43
    setAddress(roninMainnet, DefaultContract.Pyth.key(), 0x2880aB155794e7179c9eE2e38200202908C17B43);

    // Double check source: https://app.roninchain.com/address/0x2368dfED532842dB89b470fdE9Fd584d48D4F644
    setAddress(roninMainnet, DefaultContract.ERC721BatchTransfer.key(), 0x2368dfED532842dB89b470fdE9Fd584d48D4F644);

    // Double check source: https://app.roninchain.com/address/0x946397deDFd2f79b75a72B322944a21C3240c9c3
    setAddress(roninMainnet, DefaultContract.RoninGovernanceAdmin.key(), 0x946397deDFd2f79b75a72B322944a21C3240c9c3);

    // Double check source: https://app.roninchain.com/address/0x617c5d73662282EA7FfD231E020eCa6D2B0D552f
    setAddress(roninMainnet, DefaultContract.RoninValidatorSet.key(), 0x617c5d73662282EA7FfD231E020eCa6D2B0D552f);

    // Double check source: https://app.roninchain.com/address/0x840EBf1CA767CB690029E91856A357a43B85d035
    setAddress(roninMainnet, DefaultContract.Profile.key(), 0x840EBf1CA767CB690029E91856A357a43B85d035);

    // Double check source: https://app.roninchain.com/address/0x16A62a921e7fEC5Bf867fF5c805b662Db757B778
    setAddress(roninMainnet, DefaultContract.RoninVRFCoordinator.key(), 0x16A62a921e7fEC5Bf867fF5c805b662Db757B778);

    _setUpContracts();
  }

  function _setUpDefaultSender() private {
    _setUpSender();
  }

  function getSender() public view virtual override returns (address payable sender) {
    sender = _option.trezor ? payable(_trezorSender) : payable(_envSender);
    if (sender == address(0x0) && getCurrentNetwork() == DefaultNetwork.LocalHost.key()) {
      sender = payable(DEFAULT_SENDER);
    }
    require(sender != address(0x0), "GeneralConfig: Sender is address(0x0)");
  }

  function setAddress(TNetwork network, TContract contractType, address contractAddr) public virtual {
    string memory contractName = getContractName(contractType);
    require(
      network != TNetwork.wrap(0x0) && bytes(contractName).length != 0,
      string.concat(
        "GeneralConfig: Network or Contract Key not found. Network: ", network.chainAlias(), " Contract: ", contractName
      )
    );

    label(network, contractAddr, contractName);
    _contractAddrSet[network].add(contractAddr);
    _contractTypeMap[network][contractAddr] = contractType;
    _contractAddrMap[network][contractName] = contractAddr;
  }

  function getAddress(TNetwork network, TContract contractType) public view virtual returns (address payable) {
    return getAddressByRawData(network, getContractName(contractType));
  }

  function getAllAddresses(
    TNetwork network
  ) public view virtual returns (address payable[] memory) {
    return getAllAddressesByRawData(network);
  }

  function logSenderInfo() public view {
    console.log(
      vm.getLabel(getSender()),
      string.concat("| Balance: ".magenta(), vm.toString(getSender().balance / 1 ether), " ETHER")
    );
  }

  function buildRuntimeConfig() public virtual override {
    TNetwork currNetwork = getCurrentNetwork();

    if (_option.trezor) {
      _loadTrezorAccount();
      label(currNetwork, _trezorSender, "trezor-sender");

      return;
    }

    if (_option.sender == address(0x0)) {
      string memory env = currNetwork.env();
      try this.loadENVAccount(env) {
        label(currNetwork, _envSender, "env-sender");
        return;
      } catch { }

      if (currNetwork == DefaultNetwork.LocalHost.key() || currNetwork == TNetwork.wrap(0x0)) {
        _envSender = DEFAULT_SENDER;
        label(currNetwork, _envSender, "default-local-sender");

        return;
      }

      _envSender = address(0xdead);
      label(currNetwork, _envSender, "mock-sender");

      return;
    }

    _envSender = _option.sender;
    label(currNetwork, _option.sender, "override-sender");
  }
}
