// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterSinglePoolWithRoyalties} from "../base/RouterSinglePoolWithRoyalties.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RSPWRXykCurveMissingEnumerableETHTest is
    RouterSinglePoolWithRoyalties,
    UsingXykCurve,
    UsingMissingEnumerable,
    UsingETH
{}
