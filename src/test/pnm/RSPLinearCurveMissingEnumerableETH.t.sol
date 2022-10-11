// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterSinglePool} from "./base/PNMRouterSinglePool.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RSPLinearCurveMissingEnumerableETHTest is
    PNMRouterSinglePool,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingETH
{}
