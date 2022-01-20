// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {NoArbBondingCurve} from "../base/NoArbBondingCurve.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract NoArbLinearCurveMissingEnumerableETHTest is
    NoArbBondingCurve,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingETH
{}
