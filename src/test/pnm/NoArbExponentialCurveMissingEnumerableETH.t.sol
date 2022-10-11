// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMNoArbBondingCurve} from "./base/PNMNoArbBondingCurve.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract NoArbExponentialCurveMissingEnumerableETHTest is
    PNMNoArbBondingCurve,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingETH
{}
