// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { console } from "@forge-std-1.8.2/console.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { Contract } from "../../utils/Contract.sol";
import { ISharedArgument, SampleMigration } from "../../SampleMigration.s.sol";
import { Token } from "../../../../src/mocks/Token.sol";
import { WNT } from "../../../../src/mocks/WNT.sol";

contract Migration__20231204_DeployMockERC20 is SampleMigration {
  function _sharedArguments() internal virtual override returns (bytes memory args) {
    args = super._sharedArguments();

    ISharedArgument.SharedParameter memory param = abi.decode(args, (ISharedArgument.SharedParameter));

    param.mAXS = 0x97a9107C1793BC407d6F527b77e7fff4D812bece;
    param.mSLP = 0xa8754b9Fa15fc18BB59458815510E40a12cD2014;
    param.mWETH = 0xc99a6A985eD2Cac1ef41640596C5A5f9F4E19Ef5;
    param.mWRON = 0xe514d9DEB7966c8BE0ca922de8a064264eA6bcd4;
    param.mBERRY = 0x1B918543B518E34902e1E8dd76052BeE43C762Ff;

    config.label(DefaultNetwork.RoninMainnet.key(), param.mAXS, "AXS");
    config.label(DefaultNetwork.RoninMainnet.key(), param.mSLP, "SLP");
    config.label(DefaultNetwork.RoninMainnet.key(), param.mWETH, "WETH");
    config.label(DefaultNetwork.RoninMainnet.key(), param.mWRON, "WRON");
    config.label(DefaultNetwork.RoninMainnet.key(), param.mBERRY, "BERRY");

    args = abi.encode(param);
  }

  function run() public onlyOn(DefaultNetwork.RoninTestnet.key()) {
    ISharedArgument.SharedParameter memory param = config.sharedArguments();

    config.createFork(DefaultNetwork.RoninMainnet.key());
    config.switchTo(DefaultNetwork.RoninMainnet.key());

    uint256 mAXSTotalSupply = Token(param.mAXS).totalSupply();
    uint256 mSLPTotalSupply = Token(param.mSLP).totalSupply();
    uint256 mWETHTotalSupply = Token(param.mWETH).totalSupply();
    uint256 mBERRYTotalSupply = Token(param.mBERRY).totalSupply();

    console.log("mAXSTotalSupply", mAXSTotalSupply);
    console.log("mSLPTotalSupply", mSLPTotalSupply);
    console.log("mWETHTotalSupply", mWETHTotalSupply);
    console.log("mBERRYTotalSupply", mBERRYTotalSupply);

    config.switchTo(DefaultNetwork.RoninTestnet.key());

    Token tAXS = Token(_deployImmutable(Contract.tAXS.key(), abi.encode("Axie Infinity Shard", "AXS")));
    Token tSLP = Token(_deployImmutable(Contract.tSLP.key(), abi.encode("Smooth Love Potion", "SLP")));
    Token tWETH = Token(_deployImmutable(Contract.tWETH.key(), abi.encode("Wrapped Ether", "WETH")));
    Token tBERRY = Token(_deployImmutable(Contract.tBERRY.key(), abi.encode("BERRY", "BERRY")));

    address admin = makeAddr("admin");

    vm.startBroadcast();

    tAXS.mint(admin, mAXSTotalSupply);
    tSLP.mint(admin, mSLPTotalSupply);
    tWETH.mint(admin, mWETHTotalSupply);
    tBERRY.mint(admin, mBERRYTotalSupply);

    vm.stopBroadcast();
  }
}
