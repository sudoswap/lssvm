// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {NoArbExponentialCurve} from "../abstract/NoArbExponentialCurve.sol";
import {NoArbEnumerable} from "../abstract/NoArbEnumerable.sol";
import {NoArbToken} from "../abstract/NoArbToken.sol";

contract NoArbExponentialCurveEnumerableTokenTest is NoArbExponentialCurve, NoArbEnumerable, NoArbToken {}