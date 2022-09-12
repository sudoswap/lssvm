// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterMultiPoolWithRoyalties} from "../base/RouterMultiPoolWithRoyalties.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RMPWRXykCurveMissingEnumerableERC20Test is
    RouterMultiPoolWithRoyalties,
    UsingXykCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
