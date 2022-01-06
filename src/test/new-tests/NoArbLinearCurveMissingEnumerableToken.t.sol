// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {NoArbLinearCurve} from "../abstract/NoArbLinearCurve.sol";
import {NoArbMissingEnumerable} from "../abstract/NoArbMissingEnumerable.sol";
import {NoArbToken} from "../abstract/NoArbToken.sol";

contract NoArbLinearCurveMissingEnumerableTokenTest is
    NoArbLinearCurve,
    NoArbMissingEnumerable,
    NoArbToken
{}
