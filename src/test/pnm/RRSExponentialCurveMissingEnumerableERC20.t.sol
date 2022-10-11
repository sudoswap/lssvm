// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterRobustSwap} from "./base/PNMRouterRobustSwap.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSExponentialCurveMissingEnumerableERC20Test is
    PNMRouterRobustSwap,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
