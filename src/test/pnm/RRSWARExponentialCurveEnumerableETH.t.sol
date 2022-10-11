// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterRobustSwapWithAssetRecipient} from "./base/PNMRouterRobustSwapWithAssetRecipient.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RRSWARExponentialCurveEnumerableETHTest is
    PNMRouterRobustSwapWithAssetRecipient,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingETH
{}
