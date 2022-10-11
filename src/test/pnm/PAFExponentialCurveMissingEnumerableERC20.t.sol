// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMPairAndFactory} from "./base/PNMPairAndFactory.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract PAFExponentialCurveMissingEnumerableERC20Test is
    PNMPairAndFactory,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
