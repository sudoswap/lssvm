// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterRobustSwapWithAssetRecipient} from "./base/PNMRouterRobustSwapWithAssetRecipient.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RRSWARLinearCurveEnumerableETHTest is
    PNMRouterRobustSwapWithAssetRecipient,
    UsingLinearCurve,
    UsingEnumerable,
    UsingETH
{}
