// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterRobustSwapWithAssetRecipient} from "./base/PNMRouterRobustSwapWithAssetRecipient.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSWARLinearCurveMissingEnumerableERC20Test is
    PNMRouterRobustSwapWithAssetRecipient,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
