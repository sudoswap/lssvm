// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterRobustSwap} from "./base/PNMRouterRobustSwap.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RRSLinearCurveMissingEnumerableETHTest is
    PNMRouterRobustSwap,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingETH
{}
