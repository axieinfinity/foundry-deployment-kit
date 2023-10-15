// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { RONRegistrarController } from "@rns-contracts/RONRegistrarController.sol";

contract IntegrationTest is Test {
  function validateController(RONRegistrarController _ronController, address _publicResolver) external {
    Account memory user = makeAccount("tudo");
    uint64 duration = 30 days;
    bytes32 secret = keccak256("secret");
    string memory domain = "tudo-controller-promax";

    bytes[] memory data;
    bytes32 commitment =
      _ronController.computeCommitment(domain, user.addr, duration, secret, address(_publicResolver), data, true);

    vm.prank(user.addr);
    _ronController.commit(commitment);

    (, uint256 ronPrice) = _ronController.rentPrice(domain, duration);
    console2.log("domain price:", ronPrice);
    vm.deal(user.addr, ronPrice);

    vm.warp(block.timestamp + 1 hours);
    vm.prank(user.addr);
    // try _ronController.register{ value: ronPrice }(
    //   domain, user.addr, duration, secret, address(_publicResolver), data, true
    // ) { } catch { }
    _ronController.register{ value: ronPrice }(
      domain, user.addr, duration, secret, address(_publicResolver), data, true
    );

    // uint256 expectedId = uint256(string.concat(domain, ".ron").namehash());

    // assertEq(_rns.ownerOf(expectedId), user.addr);
  }
}
