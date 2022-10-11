// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMNoArbBondingCurve} from "./base/PNMNoArbBondingCurve.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract NoArbLinearCurveMissingEnumerableERC20Test is
    PNMNoArbBondingCurve,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
