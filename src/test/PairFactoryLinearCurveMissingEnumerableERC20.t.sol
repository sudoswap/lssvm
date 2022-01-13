// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PairFactoryBase} from "./base/PairFactoryBase.sol";
import {UsingLinearCurve} from "./mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "./mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "./mixins/UsingERC20.sol";

contract PairFactoryLinearCurveMissingEnumerableERC20Test is
    PairFactoryBase,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
