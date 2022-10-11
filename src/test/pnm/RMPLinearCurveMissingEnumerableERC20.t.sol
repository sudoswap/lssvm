// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterMultiPool} from "./base/PNMRouterMultiPool.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RMPLinearCurveMissingEnumerableERC20Test is
    PNMRouterMultiPool,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
