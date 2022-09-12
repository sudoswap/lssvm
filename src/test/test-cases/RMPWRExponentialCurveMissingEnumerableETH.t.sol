// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterMultiPoolWithRoyalties} from "../base/RouterMultiPoolWithRoyalties.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RMPWRExponentialCurveMissingEnumerableETHTest is
    RouterMultiPoolWithRoyalties,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingETH
{}
