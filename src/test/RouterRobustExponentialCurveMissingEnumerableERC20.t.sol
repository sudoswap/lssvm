// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterBase} from "./base/RouterBase.sol";
import {UsingExponentialCurve} from "./mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "./mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "./mixins/UsingERC20.sol";

contract RouterRobustExponentialCurveMissingEnumerableERC20Test is
    RouterBase,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
