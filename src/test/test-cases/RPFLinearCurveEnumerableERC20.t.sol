// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterPartialFill} from "../base/RouterPartialFill.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RPFLinearCurveEnumerableERC20Test is RouterPartialFill, UsingLinearCurve, UsingEnumerable, UsingERC20 {}
