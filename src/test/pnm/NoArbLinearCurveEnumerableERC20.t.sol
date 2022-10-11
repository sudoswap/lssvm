// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMNoArbBondingCurve} from "./base/PNMNoArbBondingCurve.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract NoArbLinearCurveEnumerableERC20Test is
    PNMNoArbBondingCurve,
    UsingLinearCurve,
    UsingEnumerable,
    UsingERC20
{}
