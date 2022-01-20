// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {NoArbBondingCurve} from "../base/NoArbBondingCurve.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract NoArbLinearCurveEnumerableERC20Test is
    NoArbBondingCurve,
    UsingLinearCurve,
    UsingEnumerable,
    UsingERC20
{}
