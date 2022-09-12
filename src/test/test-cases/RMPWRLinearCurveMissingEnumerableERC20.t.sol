// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterMultiPoolWithRoyalties} from "../base/RouterMultiPoolWithRoyalties.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RMPWRLinearCurveMissingEnumerableERC20Test is
    RouterMultiPoolWithRoyalties,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
