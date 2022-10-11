// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterMultiPool} from "./base/PNMRouterMultiPool.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RMPLinearCurveMissingEnumerableETHTest is
    PNMRouterMultiPool,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingETH
{}
