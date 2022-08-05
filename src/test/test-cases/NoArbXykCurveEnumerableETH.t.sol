// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {NoArbBondingCurve} from "../base/NoArbBondingCurve.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract NoArbXykCurveEnumerableETHTest is
    NoArbBondingCurve,
    UsingXykCurve,
    UsingEnumerable,
    UsingETH
{}
