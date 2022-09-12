// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterMultiPoolWithRoyalties} from "../base/RouterMultiPoolWithRoyalties.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RMPWRExponentialCurveMissingEnumerableERC20Test is
    RouterMultiPoolWithRoyalties,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
