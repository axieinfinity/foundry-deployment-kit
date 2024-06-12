// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;

import { Vm } from "../../dependencies/forge-std-1.8.2/src/Vm.sol";
import { IGeneralConfig } from "../interfaces/IGeneralConfig.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";

bytes constant EMPTY_ARGS = "";
Vm constant vm = Vm(LibSharedAddress.VM);
IGeneralConfig constant vme = IGeneralConfig(LibSharedAddress.VME);
