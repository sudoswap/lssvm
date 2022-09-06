// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterPartialFill} from "../base/RouterPartialFill.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RPFExponentialCurveMissingEnumerableERC20Test is
    RouterPartialFill,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
