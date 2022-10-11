// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterSinglePoolWithAssetRecipient} from "./base/PNMRouterSinglePoolWithAssetRecipient.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RSPWARExponentialCurveEnumerableETHTest is
    PNMRouterSinglePoolWithAssetRecipient,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingETH
{}
