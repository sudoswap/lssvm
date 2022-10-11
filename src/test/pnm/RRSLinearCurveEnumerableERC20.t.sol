// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterRobustSwap} from "./base/PNMRouterRobustSwap.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSLinearCurveEnumerableERC20Test is
    PNMRouterRobustSwap,
    UsingLinearCurve,
    UsingEnumerable,
    UsingERC20
{}
