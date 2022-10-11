// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterRobustSwapWithAssetRecipient} from "./base/PNMRouterRobustSwapWithAssetRecipient.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSWARLinearCurveEnumerableERC20Test is
    PNMRouterRobustSwapWithAssetRecipient,
    UsingLinearCurve,
    UsingEnumerable,
    UsingERC20
{}
