// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustSwap} from "../base/RouterRobustSwap.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RRSXykCurveEnumerableETHTest is
    RouterRobustSwap,
    UsingXykCurve,
    UsingEnumerable,
    UsingETH
{}
