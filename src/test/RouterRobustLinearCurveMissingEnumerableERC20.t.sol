// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterBase} from "./base/RouterBase.sol";
import {UsingLinearCurve} from "./mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "./mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "./mixins/UsingERC20.sol";

contract RouterRobustLinearCurveMissingEnumerableERC20Test is
    RouterBase,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
