// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustBaseERC20} from "../base/RouterRobustBaseERC20.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RouterRobustExponentialCurveMissingEnumerableERC20Test is
    RouterRobustBaseERC20,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
