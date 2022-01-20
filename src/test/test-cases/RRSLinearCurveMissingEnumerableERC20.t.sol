// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustSwap} from "../base/RouterRobustSwap.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSLinearCurveMissingEnumerableERC20Test is
    RouterRobustSwap,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
