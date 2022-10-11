// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMPairAndFactory} from "./base/PNMPairAndFactory.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract PAFExponentialCurveMissingEnumerableETHTest is
    PNMPairAndFactory,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingETH
{}
