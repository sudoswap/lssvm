// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterPartialFill} from "../base/RouterPartialFill.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RPFLinearCurveEnumerableETHTest is
    RouterPartialFill,
    UsingLinearCurve,
    UsingEnumerable,
    UsingETH
{}
