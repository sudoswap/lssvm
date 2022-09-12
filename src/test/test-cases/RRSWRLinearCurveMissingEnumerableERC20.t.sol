// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustSwapWithRoyalties} from "../base/RouterRobustSwapWithRoyalties.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSWRLinearCurveMissingEnumerableERC20Test is
    RouterRobustSwapWithRoyalties,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
