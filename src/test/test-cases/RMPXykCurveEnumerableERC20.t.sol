// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterMultiPool} from "../base/RouterMultiPool.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RMPXykCurveEnumerableERC20Test is
    RouterMultiPool,
    UsingXykCurve,
    UsingEnumerable,
    UsingERC20
{}
