// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library LibSig {
  /**
   * @dev Merges the ECDSA values into a single signature bytes
   * @param v ECDSA recovery value
   * @param r ECDSA r value
   * @param s ECDSA s value
   * @return signature Combined signature bytes
   */
  function merge(uint8 v, bytes32 r, bytes32 s) internal pure returns (bytes memory signature) {
    signature = new bytes(65);
    assembly ("memory-safe") {
      mstore(add(signature, 0x20), r)
      mstore(add(signature, 0x40), s)
      mstore8(add(signature, 0x60), v)
    }
  }

  /**
   * @dev Splits the signature bytes into ECDSA values
   * @param signature Signature bytes to split
   * @return r s v Tuple of ECDSA values
   */
  function split(bytes calldata signature) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
    assembly ("memory-safe") {
      r := calldataload(signature.offset)
      s := calldataload(add(signature.offset, 0x20))
      v := byte(0, calldataload(add(signature.offset, 0x40)))
    }
  }
}
