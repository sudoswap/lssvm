// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterSinglePool} from "./base/PNMRouterSinglePool.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RSPExponentialCurveEnumerableERC20Test is
    PNMRouterSinglePool,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingERC20
{}
