// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PairFactoryBase} from "../base/PairFactoryBase.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract PairFactoryLinearCurveMissingEnumerableETHTest is PairFactoryBase, UsingLinearCurve, UsingMissingEnumerable, UsingETH {}
