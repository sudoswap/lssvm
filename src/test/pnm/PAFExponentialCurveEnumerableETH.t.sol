// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMPairAndFactory} from "./base/PNMPairAndFactory.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract PAFExponentialCurveEnumerableETHTest is
    PNMPairAndFactory,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingETH
{}
