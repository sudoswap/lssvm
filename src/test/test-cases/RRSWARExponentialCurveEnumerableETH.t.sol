// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustSwapWithAssetRecipient} from "../base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RRSWARExponentialCurveEnumerableETHTest is
    RouterRobustSwapWithAssetRecipient,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingETH
{}
