// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { SampleProxy } from "src/mocks/SampleProxy.sol";
import { Contract } from "../utils/Contract.sol";
import { TContract } from "../../types/TContract.sol";
import { ISharedArgument, SampleMigration } from "../SampleMigration.s.sol";
import { DeployInfo, LibDeploy } from "../../libraries/LibDeploy.sol";
import { LibString } from "../../../dependencies/solady-0.0.206/src/utils/LibString.sol";

contract SampleProxyV2Deploy is SampleMigration {
  using LibString for bytes32;

  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.SharedParameter memory param = ISharedArgument(address(vme)).sharedArguments();
    args = abi.encodeCall(SampleProxy.initialize, (param.proxyMessage));
  }

  function run() public virtual returns (SampleProxy instance) {
    instance = SampleProxy(_deployProxy(Contract.SampleProxy.key()));
    assertEq(instance.getMessage(), ISharedArgument(address(vme)).sharedArguments().proxyMessage);
  }

  function _deployProxy(
    TContract contractType,
    string memory artifactName,
    address proxyAdmin,
    uint256 callValue,
    address by,
    bytes memory callData,
    bytes memory logicConstructorArgs
  )
    internal
    virtual
    override
    logFn(string.concat("_deployProxy ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable deployed)
  {
    string memory contractName = vme.getContractName(contractType);

    deployed = LibDeploy.deployTransparentProxyV2({
      implInfo: DeployInfo({
        callValue: 0,
        by: by,
        contractName: contractName,
        absolutePath: vme.getContractAbsolutePath(contractType),
        artifactName: bytes(artifactName).length == 0 ? contractName : artifactName,
        constructorArgs: logicConstructorArgs
      }),
      callValue: callValue,
      proxyAdmin: proxyAdmin,
      callData: callData
    });

    vme.setAddress(network(), contractType, deployed);
  }
}
