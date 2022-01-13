// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PairFactoryBase} from "./base/PairFactoryBase.sol";
import {UsingLinearCurve} from "./mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "./mixins/UsingEnumerable.sol";
import {UsingERC20} from "./mixins/UsingERC20.sol";

contract PairFactoryLinearCurveEnumerableERC20Test is PairFactoryBase, UsingLinearCurve, UsingEnumerable, UsingERC20 {}
