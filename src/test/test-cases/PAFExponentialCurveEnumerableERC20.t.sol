// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PairAndFactory} from "../base/PairAndFactory.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract PAFExponentialCurveEnumerableERC20Test is
    PairAndFactory,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingERC20
{}
