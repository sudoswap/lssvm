// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMNoArbBondingCurve} from "./base/PNMNoArbBondingCurve.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract NoArbLinearCurveMissingEnumerableETHTest is
    PNMNoArbBondingCurve,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingETH
{}
