// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterRobustSwapWithAssetRecipient} from "./base/PNMRouterRobustSwapWithAssetRecipient.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RRSWARExponentialCurveMissingEnumerableERC20Test is
    PNMRouterRobustSwapWithAssetRecipient,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
