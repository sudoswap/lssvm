// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PairAndFactory} from "../base/PairAndFactory.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract PAFLinearCurveMissingEnumerableETHTest is
    PairAndFactory,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingETH
{}
