// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "../../lib/forge-std/src/Vm.sol";
import { IGeneralConfig } from "../interfaces/IGeneralConfig.sol";
import { LibSharedAddress } from "../libraries/LibSharedAddress.sol";

bytes constant EMPTY_ARGS = "";
Vm constant vm = Vm(LibSharedAddress.VM);
IGeneralConfig constant vme = IGeneralConfig(LibSharedAddress.VME);
