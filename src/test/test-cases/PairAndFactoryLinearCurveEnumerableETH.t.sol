// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PairAndFactory} from "../base/PairAndFactory.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract PairAndFactoryLinearCurveEnumerableETHTest is PairAndFactory, UsingLinearCurve, UsingEnumerable, UsingETH {}
