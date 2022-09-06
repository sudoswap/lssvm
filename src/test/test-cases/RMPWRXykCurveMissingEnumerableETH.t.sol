// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterMultiPoolWithRoyalties} from "../base/RouterMultiPoolWithRoyalties.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RMPWRXykCurveMissingEnumerableETHTest is
    RouterMultiPoolWithRoyalties,
    UsingXykCurve,
    UsingMissingEnumerable,
    UsingETH
{}
