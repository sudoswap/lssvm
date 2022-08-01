// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustSwapWithAssetRecipient} from "../base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSWARXykCurveEnumerableERC20Test is
    RouterRobustSwapWithAssetRecipient,
    UsingXykCurve,
    UsingEnumerable,
    UsingERC20
{}
