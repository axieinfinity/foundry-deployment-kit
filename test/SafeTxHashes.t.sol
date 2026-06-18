// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "../dependencies/forge-std-1.9.5/src/Test.sol";

import { computeSafeTxHashes } from "script/utils/Helpers.sol";

contract SafeTxHashesTest is Test {
  // Reference values produced independently with `cast` using the same inputs as the assertions below
  // (Safe 0x9D05...902a on Ronin mainnet chainId 2020, nonce 318, to 0x..bEEF, value 0, data 0x12345678).
  // This guards against any transposition of fields / wrong typehash in `computeSafeTxHashes`.
  function testConcrete_ComputeSafeTxHashes_MatchesCastReference() public pure {
    (bytes32 domainHash, bytes32 messageHash, bytes32 safeTxHash) = computeSafeTxHashes({
      chainId: 2020,
      safe: 0x9D05D1F5b0424F8fDE534BC196FFB6Dd211D902a,
      to: 0x000000000000000000000000000000000000bEEF,
      value: 0,
      data: hex"12345678",
      nonce: 318
    });

    assertEq(domainHash, 0x7a5604929f746fb1dd6cb5b7884f41ced5033360310c6f96178720a156cf460c, "domain hash");
    assertEq(messageHash, 0x8264c8c2d184f126c0ab043d4c8969ff36d393e3827b1949524718d2450c2781, "message hash");
    assertEq(safeTxHash, 0x0a2b1abe236ee4c4b28f510d14fa5d704d74e1a3ba8093217834cc9d4b8b229f, "safe tx hash");
  }
}
