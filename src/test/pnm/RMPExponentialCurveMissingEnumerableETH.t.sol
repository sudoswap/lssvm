// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterMultiPool} from "./base/PNMRouterMultiPool.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RMPExponentialCurveMissingEnumerableETHTest is
    PNMRouterMultiPool,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingETH
{}
