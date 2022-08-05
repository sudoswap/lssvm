// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustSwapWithAssetRecipient} from "../base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RRSWARXykCurveMissingEnumerableETHTest is
    RouterRobustSwapWithAssetRecipient,
    UsingXykCurve,
    UsingMissingEnumerable,
    UsingETH
{}
