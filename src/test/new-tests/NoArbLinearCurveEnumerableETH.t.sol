// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {NoArbLinearCurve} from "../abstract/NoArbLinearCurve.sol";
import {NoArbEnumerable} from "../abstract/NoArbEnumerable.sol";
import {NoArbETH} from "../abstract/NoArbETH.sol";

contract NoArbLinearCurveEnumerableETHTest is NoArbLinearCurve, NoArbEnumerable, NoArbETH {}