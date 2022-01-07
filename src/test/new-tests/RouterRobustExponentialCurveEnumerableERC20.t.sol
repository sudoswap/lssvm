// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustBaseERC20} from "../base/RouterRobustBaseERC20.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RouterRobustExponentialCurveEnumerableERC20Test is
    RouterRobustBaseERC20,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingERC20
{}
