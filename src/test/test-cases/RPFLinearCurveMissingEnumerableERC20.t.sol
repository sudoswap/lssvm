// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterPartialFill} from "../base/RouterPartialFill.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RPFLinearCurveMissingEnumerableERC20Test is
    RouterPartialFill,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
