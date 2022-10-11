// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterRobustSwapWithAssetRecipient} from "./base/PNMRouterRobustSwapWithAssetRecipient.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RRSWARLinearCurveMissingEnumerableETHTest is
    PNMRouterRobustSwapWithAssetRecipient,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingETH
{}
