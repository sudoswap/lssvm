// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustSwapWithAssetRecipient} from "../base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSWARXykCurveMissingEnumerableERC20Test is
    RouterRobustSwapWithAssetRecipient,
    UsingXykCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
