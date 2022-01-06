// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {NoArbLinearCurve} from "../abstract/NoArbLinearCurve.sol";
import {NoArbEnumerable} from "../abstract/NoArbEnumerable.sol";
import {NoArbToken} from "../abstract/NoArbToken.sol";

contract NoArbLinearCurveEnumerableTokenTest is
    NoArbLinearCurve,
    NoArbEnumerable,
    NoArbToken
{}
