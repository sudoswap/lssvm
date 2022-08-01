// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PairAndFactory} from "../base/PairAndFactory.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract PAFXykCurveMissingEnumerableETHTest is
    PairAndFactory,
    UsingXykCurve,
    UsingMissingEnumerable,
    UsingETH
{}
