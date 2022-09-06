// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustSwapWithRoyalties} from "../base/RouterRobustSwapWithRoyalties.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RRSWRExponentialCurveMissingEnumerableETHTest is
    RouterRobustSwapWithRoyalties,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingETH
{}
