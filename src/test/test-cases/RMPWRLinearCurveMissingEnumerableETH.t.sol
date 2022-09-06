// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterMultiPoolWithRoyalties} from "../base/RouterMultiPoolWithRoyalties.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RMPWRLinearCurveMissingEnumerableETHTest is
    RouterMultiPoolWithRoyalties,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingETH
{}
