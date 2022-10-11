// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterMultiPool} from "./base/PNMRouterMultiPool.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RMPExponentialCurveMissingEnumerableERC20Test is
    PNMRouterMultiPool,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
