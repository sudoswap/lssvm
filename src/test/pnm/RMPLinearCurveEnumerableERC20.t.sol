// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterMultiPool} from "./base/PNMRouterMultiPool.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RMPLinearCurveEnumerableERC20Test is
    PNMRouterMultiPool,
    UsingLinearCurve,
    UsingEnumerable,
    UsingERC20
{}
