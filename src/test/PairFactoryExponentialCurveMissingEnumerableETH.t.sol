// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PairFactoryBase} from "./base/PairFactoryBase.sol";
import {UsingExponentialCurve} from "./mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "./mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "./mixins/UsingETH.sol";

contract PairFactoryExponentialCurveMissingEnumerableETHTest is PairFactoryBase, UsingExponentialCurve, UsingMissingEnumerable, UsingETH {}
