// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterMultiPool} from "../base/RouterMultiPool.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RMPLinearCurveMissingEnumerableERC20Test is
    RouterMultiPool,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
