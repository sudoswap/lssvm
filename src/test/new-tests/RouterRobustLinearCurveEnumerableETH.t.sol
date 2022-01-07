// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustBaseETH} from "../base/RouterRobustBaseETH.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RouterRobustLinearCurveEnumerableETHTest is
    RouterRobustBaseETH,
    UsingLinearCurve,
    UsingEnumerable,
    UsingETH
{}
