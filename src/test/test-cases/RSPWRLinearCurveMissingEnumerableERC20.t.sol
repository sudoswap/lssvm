// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterSinglePoolWithRoyalties} from "../base/RouterSinglePoolWithRoyalties.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RSPWRLinearCurveMissingEnumerableERC20Test is
    RouterSinglePoolWithRoyalties,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
