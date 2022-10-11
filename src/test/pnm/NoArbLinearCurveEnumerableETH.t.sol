// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMNoArbBondingCurve} from "./base/PNMNoArbBondingCurve.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract NoArbLinearCurveEnumerableETHTest is
    PNMNoArbBondingCurve,
    UsingLinearCurve,
    UsingEnumerable,
    UsingETH
{}
