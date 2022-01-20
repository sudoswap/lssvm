// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {NoArbBondingCurve} from "../base/NoArbBondingCurve.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract NoArbLinearCurveMissingEnumerableERC20Test is
    NoArbBondingCurve,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
