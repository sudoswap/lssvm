// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PairFactoryBase} from "./base/PairFactoryBase.sol";
import {UsingExponentialCurve} from "./mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "./mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "./mixins/UsingERC20.sol";

contract PairFactoryExponentialCurveMissingEnumerableERC20Test is
    PairFactoryBase,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
