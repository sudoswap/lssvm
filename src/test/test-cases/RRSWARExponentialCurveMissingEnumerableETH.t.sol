// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustSwapWithAssetRecipient} from "../base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RRSWARExponentialCurveMissingEnumerableETHTest is
    RouterRobustSwapWithAssetRecipient,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingETH
{}
