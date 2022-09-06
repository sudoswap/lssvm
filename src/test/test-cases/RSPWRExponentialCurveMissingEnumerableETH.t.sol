// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterSinglePoolWithRoyalties} from "../base/RouterSinglePoolWithRoyalties.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RSPWRExponentialCurveMissingEnumerableETHTest is
    RouterSinglePoolWithRoyalties,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingETH
{}
