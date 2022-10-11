// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterSinglePool} from "./base/PNMRouterSinglePool.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RSPLinearCurveEnumerableETHTest is
    PNMRouterSinglePool,
    UsingLinearCurve,
    UsingEnumerable,
    UsingETH
{}
