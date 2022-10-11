// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMPairAndFactory} from "./base/PNMPairAndFactory.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract PAFLinearCurveMissingEnumerableETHTest is
    PNMPairAndFactory,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingETH
{}
