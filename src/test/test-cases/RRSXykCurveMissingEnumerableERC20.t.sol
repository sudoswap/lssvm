// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustSwap} from "../base/RouterRobustSwap.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSXykCurveMissingEnumerableERC20Test is
    RouterRobustSwap,
    UsingXykCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
