// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterRobustSwapWithAssetRecipient} from "../base/RouterRobustSwapWithAssetRecipient.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSWARLinearCurveMissingEnumerableERC20Test is
    RouterRobustSwapWithAssetRecipient,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
