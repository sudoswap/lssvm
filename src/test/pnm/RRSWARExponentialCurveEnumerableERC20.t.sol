// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterRobustSwapWithAssetRecipient} from "./base/PNMRouterRobustSwapWithAssetRecipient.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSWARExponentialCurveEnumerableERC20Test is
    PNMRouterRobustSwapWithAssetRecipient,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingERC20
{}
