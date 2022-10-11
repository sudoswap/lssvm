// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterSinglePool} from "./base/PNMRouterSinglePool.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RSPLinearCurveMissingEnumerableERC20Test is
    PNMRouterSinglePool,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
