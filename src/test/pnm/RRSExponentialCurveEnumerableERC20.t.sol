// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterRobustSwap} from "./base/PNMRouterRobustSwap.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSExponentialCurveEnumerableERC20Test is
    PNMRouterRobustSwap,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingERC20
{}
