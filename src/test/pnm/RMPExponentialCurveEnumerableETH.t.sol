// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterMultiPool} from "./base/PNMRouterMultiPool.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RMPExponentialCurveEnumerableETHTest is
    PNMRouterMultiPool,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingETH
{}
