// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRoninTransparentProxy {
    function changeAdmin(address newAdmin) external;

    function upgradeTo(address newImplementation) external;

    function implementation() external view returns (address);

    function admin() external view returns (address);
}