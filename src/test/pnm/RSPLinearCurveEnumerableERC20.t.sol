// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterSinglePool} from "./base/PNMRouterSinglePool.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RSPLinearCurveEnumerableERC20Test is
    PNMRouterSinglePool,
    UsingLinearCurve,
    UsingEnumerable,
    UsingERC20
{}
