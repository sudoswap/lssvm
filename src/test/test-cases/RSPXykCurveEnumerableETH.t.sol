// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterSinglePool} from "../base/RouterSinglePool.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RSPXykCurveEnumerableETHTest is
    RouterSinglePool,
    UsingXykCurve,
    UsingEnumerable,
    UsingETH
{}
