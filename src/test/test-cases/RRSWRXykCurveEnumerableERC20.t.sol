// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustSwapWithRoyalties} from "../base/RouterRobustSwapWithRoyalties.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSWRXykCurveEnumerableERC20Test is
    RouterRobustSwapWithRoyalties,
    UsingXykCurve,
    UsingEnumerable,
    UsingERC20
{}
