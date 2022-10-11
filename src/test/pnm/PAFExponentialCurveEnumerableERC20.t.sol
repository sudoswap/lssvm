// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMPairAndFactory} from "./base/PNMPairAndFactory.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract PAFExponentialCurveEnumerableERC20Test is
    PNMPairAndFactory,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingERC20
{}
