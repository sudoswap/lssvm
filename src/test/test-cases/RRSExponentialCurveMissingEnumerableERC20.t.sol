// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustSwap} from "../base/RouterRobustSwap.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSExponentialCurveMissingEnumerableERC20Test is
    RouterRobustSwap,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
