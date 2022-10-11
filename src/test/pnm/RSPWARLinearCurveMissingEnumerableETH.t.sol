// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterSinglePoolWithAssetRecipient} from "./base/PNMRouterSinglePoolWithAssetRecipient.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RSPWARLinearCurveMissingEnumerableETHTest is
    PNMRouterSinglePoolWithAssetRecipient,
    UsingLinearCurve,
    UsingMissingEnumerable,
    UsingETH
{}
