// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterPartialFill} from "../base/RouterPartialFill.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RPFLinearCurveMissingEnumerableETHTest is
    RouterPartialFill,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingETH
{}
