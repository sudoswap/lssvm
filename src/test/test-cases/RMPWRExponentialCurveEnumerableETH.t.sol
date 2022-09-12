// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterMultiPoolWithRoyalties} from "../base/RouterMultiPoolWithRoyalties.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RMPWRExponentialCurveEnumerableETHTest is
    RouterMultiPoolWithRoyalties,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingETH
{}
