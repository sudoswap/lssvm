// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {NoArbExponentialCurve} from "../abstract/NoArbExponentialCurve.sol";
import {NoArbMissingEnumerable} from "../abstract/NoArbMissingEnumerable.sol";
import {NoArbETH} from "../abstract/NoArbETH.sol";

contract NoArbExponentialCurveMissingEnumerableETHTest is
    NoArbExponentialCurve,
    NoArbMissingEnumerable,
    NoArbETH
{}
