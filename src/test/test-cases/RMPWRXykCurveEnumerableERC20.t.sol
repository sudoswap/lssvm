// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterMultiPoolWithRoyalties} from "../base/RouterMultiPoolWithRoyalties.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RMPWRXykCurveEnumerableERC20Test is
    RouterMultiPoolWithRoyalties,
    UsingXykCurve,
    UsingEnumerable,
    UsingERC20
{}
