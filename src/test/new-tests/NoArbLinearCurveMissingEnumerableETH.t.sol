// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {NoArbLinearCurve} from "../abstract/NoArbLinearCurve.sol";
import {NoArbMissingEnumerable} from "../abstract/NoArbMissingEnumerable.sol";
import {NoArbETH} from "../abstract/NoArbETH.sol";

contract NoArbLinearCurveMissingEnumerableETHTest is
    NoArbLinearCurve,
    NoArbMissingEnumerable,
    NoArbETH
{}
