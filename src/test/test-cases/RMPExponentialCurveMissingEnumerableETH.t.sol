// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterMultiPool} from "../base/RouterMultiPool.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RMPExponentialCurveMissingEnumerableETHTest is
    RouterMultiPool,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingETH
{}
