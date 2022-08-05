// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {NoArbBondingCurve} from "../base/NoArbBondingCurve.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract NoArbXykCurveMissingEnumerableETHTest is
    NoArbBondingCurve,
    UsingXykCurve,
    UsingMissingEnumerable,
    UsingETH
{}
