// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {NoArbExponentialCurve} from "../abstract/NoArbExponentialCurve.sol";
import {NoArbMissingEnumerable} from "../abstract/NoArbMissingEnumerable.sol";
import {NoArbToken} from "../abstract/NoArbToken.sol";

contract NoArbExponentialCurveMissingEnumerableTokenTest is
    NoArbExponentialCurve,
    NoArbMissingEnumerable,
    NoArbToken
{}
