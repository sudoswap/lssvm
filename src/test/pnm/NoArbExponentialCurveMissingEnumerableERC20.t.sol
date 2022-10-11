// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMNoArbBondingCurve} from "./base/PNMNoArbBondingCurve.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract NoArbExponentialCurveMissingEnumerableERC20Test is
    PNMNoArbBondingCurve,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
