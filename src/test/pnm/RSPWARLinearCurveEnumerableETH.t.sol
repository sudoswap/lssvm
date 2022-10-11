// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterSinglePoolWithAssetRecipient} from "./base/PNMRouterSinglePoolWithAssetRecipient.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RSPWARLinearCurveEnumerableETHTest is
    PNMRouterSinglePoolWithAssetRecipient,
    UsingLinearCurve,
    UsingEnumerable,
    UsingETH
{}
