// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterMultiPool} from "../base/RouterMultiPool.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RMPXykCurveMissingEnumerableERC20Test is
    RouterMultiPool,
    UsingXykCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
