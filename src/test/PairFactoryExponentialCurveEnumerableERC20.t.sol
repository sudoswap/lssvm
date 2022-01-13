// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PairFactoryBase} from "./base/PairFactoryBase.sol";
import {UsingExponentialCurve} from "./mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "./mixins/UsingEnumerable.sol";
import {UsingERC20} from "./mixins/UsingERC20.sol";

contract PairFactoryExponentialCurveEnumerableERC20Test is
    PairFactoryBase,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingERC20
{}
