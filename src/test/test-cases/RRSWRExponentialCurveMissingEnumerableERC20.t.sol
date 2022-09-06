// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustSwapWithRoyalties} from "../base/RouterRobustSwapWithRoyalties.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSWRExponentialCurveMissingEnumerableERC20Test is
    RouterRobustSwapWithRoyalties,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
